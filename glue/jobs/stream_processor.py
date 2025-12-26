"""
AWS Glue Streaming Job - E-commerce Click Attribution
Processes click and checkout events from Kinesis streams
"""

import sys
import os

os.environ['AWS_DEFAULT_REGION'] = 'ap-southeast-1'
os.environ['AWS_REGION'] = 'ap-southeast-1'

from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import Window
from pyspark.sql.functions import (
    col, from_json, to_timestamp, current_timestamp,
    unix_timestamp, expr, row_number
)
from pyspark.sql.types import (
    StructType, StructField, StringType, DoubleType, 
    IntegerType, ArrayType, TimestampType
)

# Get job parameters
args = getResolvedOptions(sys.argv, [
    'JOB_NAME',
    'CLICKS_STREAM_NAME',
    'CHECKOUTS_STREAM_NAME',
    'CHECKPOINT_LOCATION',
    'DATABASE_HOST',
    'DATABASE_NAME',
    'DATABASE_USER',
    'DATABASE_PASSWORD',
    'DATABASE_PORT'
])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Spark configuration
spark.conf.set("spark.sql.streaming.schemaInference", "true")
spark.conf.set("spark.sql.streaming.checkpointLocation", args['CHECKPOINT_LOCATION'])
spark.conf.set("spark.sql.adaptive.enabled", "true")

# PostgreSQL configuration
postgres_url = f"jdbc:postgresql://{args['DATABASE_HOST']}:{args['DATABASE_PORT']}/{args['DATABASE_NAME']}"
postgres_properties = {
    "user": args['DATABASE_USER'],
    "password": args['DATABASE_PASSWORD'],
    "driver": "org.postgresql.Driver"
}

print(f"Connecting to PostgreSQL at {args['DATABASE_HOST']}:{args['DATABASE_PORT']}/{args['DATABASE_NAME']}")

# Define schemas for Kinesis data
click_schema = StructType([
    StructField("event_id", StringType(), True),
    StructField("user_id", StringType(), True),
    StructField("product_id", StringType(), True),
    StructField("product_name", StringType(), True),
    StructField("product_category", StringType(), True),
    StructField("product_price", DoubleType(), True),
    StructField("timestamp", StringType(), True),
    StructField("session_id", StringType(), True),
    StructField("device_type", StringType(), True),
    StructField("page_url", StringType(), True),
    StructField("referrer", StringType(), True)
])

item_schema = StructType([
    StructField("product_id", StringType(), True),
    StructField("product_name", StringType(), True),
    StructField("price", DoubleType(), True),
    StructField("quantity", IntegerType(), True)
])

checkout_schema = StructType([
    StructField("event_id", StringType(), True),
    StructField("user_id", StringType(), True),
    StructField("timestamp", StringType(), True),
    StructField("session_id", StringType(), True),
    StructField("items", ArrayType(item_schema), True),
    StructField("total_amount", DoubleType(), True),
    StructField("payment_method", StringType(), True)
])


def read_kinesis_stream(stream_name, schema):
    """Read and parse data from Kinesis stream"""
    print(f"Reading from Kinesis stream: {stream_name}")
    
    kinesis_df = spark.readStream \
        .format("kinesis") \
        .option("streamName", stream_name) \
        .option("region", "ap-southeast-1") \
        .option("endpointUrl", "https://kinesis.ap-southeast-1.amazonaws.com") \
        .option("initialPosition", "TRIM_HORIZON") \
        .option("format", "json") \
        .load()
    
    # Parse JSON data
    parsed_df = kinesis_df.selectExpr("CAST(data AS STRING) as json_data") \
        .select(from_json(col("json_data"), schema).alias("data")) \
        .select("data.*")
    
    # Convert timestamp string to timestamp type
    parsed_df = parsed_df.withColumn(
        "event_timestamp",
        to_timestamp(col("timestamp"), "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'")
    )
    
    return parsed_df


def write_to_postgres(batch_df, batch_id, table_name):
    """Write batch DataFrame to PostgreSQL table"""
    try:
        row_count = batch_df.count()
        
        if row_count > 0:
            batch_df.write \
                .jdbc(
                    url=postgres_url,
                    table=table_name,
                    mode="append",
                    properties=postgres_properties
                )
            print(f"✅ Batch {batch_id}: Written {row_count} records to {table_name}")
        else:
            print(f"⏭️  Batch {batch_id}: No records to write to {table_name}")
            
    except Exception as e:
        print(f"❌ Error writing batch {batch_id} to {table_name}: {str(e)}")
        # Don't raise - let job continue processing other batches


def process_attribution_batch(batch_df, batch_id):
    """
    Process attribution for a micro-batch using first-click attribution.
    Applies window functions to find the earliest click for each checkout.
    """
    try:
        row_count = batch_df.count()
        
        if row_count == 0:
            print(f"⏭️  Batch {batch_id}: No records to process for attribution")
            return
        
        print(f"🔄 Processing attribution for batch {batch_id} with {row_count} records")
        
        # Apply window function to get first (earliest) click for each checkout
        window_spec = Window.partitionBy("checkout_event_id").orderBy("click_event_timestamp")
        
        attributed_df = batch_df \
            .withColumn("click_rank", row_number().over(window_spec)) \
            .filter(col("click_rank") == 1) \
            .select(
                col("checkout_event_id").alias("checkout_id"),
                col("checkout_user_id").alias("user_id"),
                col("checkout_event_timestamp").alias("checkout_timestamp"),
                col("click_event_id").alias("attributed_click_id"),
                col("click_product_id").alias("attributed_product_id"),
                col("click_product_name").alias("attributed_product_name"),
                col("click_product_category").alias("attributed_category"),
                col("click_referrer").alias("traffic_source"),
                col("click_device_type").alias("device_type"),
                col("click_event_timestamp").alias("first_click_timestamp"),
                col("checkout_total_amount").alias("revenue"),
                current_timestamp().alias("processed_at")
            )
        
        # Calculate time between click and checkout
        final_df = attributed_df.withColumn(
            "attribution_window_seconds",
            unix_timestamp(col("checkout_timestamp")) - unix_timestamp(col("first_click_timestamp"))
        )
        
        # Write to PostgreSQL
        write_to_postgres(final_df, batch_id, "session_attribution")
        
    except Exception as e:
        print(f"❌ Error processing attribution batch {batch_id}: {str(e)}")


# Read Kinesis streams
print("=" * 60)
print("Starting E-commerce Click Attribution Streaming Job")
print("=" * 60)

clicks_df = read_kinesis_stream(args['CLICKS_STREAM_NAME'], click_schema)
checkouts_df = read_kinesis_stream(args['CHECKOUTS_STREAM_NAME'], checkout_schema)

# Add watermarks for handling late data
clicks_with_watermark = clicks_df.withWatermark("event_timestamp", "5 minutes")
checkouts_with_watermark = checkouts_df.withWatermark("event_timestamp", "5 minutes")

print("Watermarks configured: 5 minutes for late data handling")

# Perform stream-to-stream join
# Join checkouts with clicks that occurred within 1 hour before checkout
print("Configuring stream-to-stream join with 1-hour attribution window")

joined_df = checkouts_with_watermark.alias("checkout") \
    .join(
        clicks_with_watermark.alias("click"),
        (col("checkout.user_id") == col("click.user_id")) &
        (col("click.event_timestamp") <= col("checkout.event_timestamp")) &
        (col("click.event_timestamp") >= col("checkout.event_timestamp") - expr("INTERVAL 1 HOUR")),
        "inner"
    ) \
    .select(
        col("checkout.event_id").alias("checkout_event_id"),
        col("checkout.user_id").alias("checkout_user_id"),
        col("checkout.event_timestamp").alias("checkout_event_timestamp"),
        col("checkout.total_amount").alias("checkout_total_amount"),
        col("click.event_id").alias("click_event_id"),
        col("click.product_id").alias("click_product_id"),
        col("click.product_name").alias("click_product_name"),
        col("click.product_category").alias("click_product_category"),
        col("click.referrer").alias("click_referrer"),
        col("click.device_type").alias("click_device_type"),
        col("click.event_timestamp").alias("click_event_timestamp")
    )

# Start streaming queries
print("=" * 60)
print("Starting 3 streaming queries:")
print("  1. Attribution (session_attribution table)")
print("  2. Raw Clicks (events_clicks table)")
print("  3. Raw Checkouts (events_checkouts table)")
print("=" * 60)

# Query 1: Attribution stream
attribution_query = joined_df.writeStream \
    .foreachBatch(process_attribution_batch) \
    .option("checkpointLocation", f"{args['CHECKPOINT_LOCATION']}/attribution") \
    .outputMode("append") \
    .trigger(processingTime='30 seconds') \
    .start()

# Query 2: Raw clicks stream
clicks_query = clicks_df \
    .select(
        col("event_id"),
        col("user_id"),
        col("session_id"),
        col("product_id"),
        col("product_category"),
        col("referrer"),
        col("device_type"),
        col("event_timestamp")
    ) \
    .writeStream \
    .foreachBatch(lambda df, batch_id: write_to_postgres(df, batch_id, "events_clicks")) \
    .option("checkpointLocation", f"{args['CHECKPOINT_LOCATION']}/clicks") \
    .outputMode("append") \
    .trigger(processingTime='30 seconds') \
    .start()

# Query 3: Raw checkouts stream
checkouts_query = checkouts_df \
    .select(
        col("event_id"),
        col("user_id"),
        col("session_id"),
        col("total_amount"),
        col("payment_method"),
        col("event_timestamp")
    ) \
    .writeStream \
    .foreachBatch(lambda df, batch_id: write_to_postgres(df, batch_id, "events_checkouts")) \
    .option("checkpointLocation", f"{args['CHECKPOINT_LOCATION']}/checkouts") \
    .outputMode("append") \
    .trigger(processingTime='30 seconds') \
    .start()

print("✅ All streaming queries started successfully")
print("📊 Processing data every 30 seconds...")
print("🔄 Job will run continuously until stopped")

# Wait for termination
attribution_query.awaitTermination()
clicks_query.awaitTermination()
checkouts_query.awaitTermination()

job.commit()