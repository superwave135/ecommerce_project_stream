"""
AWS Glue Streaming Job - E-commerce Click Attribution
Processes click and checkout events from Kinesis to perform first-click attribution
"""

import sys
import os

# FORCE AWS REGION - CRITICAL FOR KINESIS
os.environ['AWS_DEFAULT_REGION'] = 'ap-southeast-1'
os.environ['AWS_REGION'] = 'ap-southeast-1'

from datetime import datetime
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql import DataFrame, Window
from pyspark.sql.functions import (
    col, from_json, to_timestamp, current_timestamp, 
    window, first, min, unix_timestamp, lit, expr, row_number
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

# Configure Spark for streaming
spark.conf.set("spark.sql.streaming.schemaInference", "true")
spark.conf.set("spark.sql.streaming.checkpointLocation", args['CHECKPOINT_LOCATION'])
spark.conf.set("spark.sql.adaptive.enabled", "true")

# Define schemas
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

# PostgreSQL connection properties
postgres_properties = {
    "user": args['DATABASE_USER'],
    "password": args['DATABASE_PASSWORD'],
    "driver": "org.postgresql.Driver"
}

postgres_url = f"jdbc:postgresql://{args['DATABASE_HOST']}:{args['DATABASE_PORT']}/{args['DATABASE_NAME']}"


def read_kinesis_stream(stream_name, schema):
    """Read from Kinesis stream and parse JSON data"""
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
    """Write DataFrame to PostgreSQL"""
    try:
        if batch_df.count() > 0:
            batch_df.write \
                .jdbc(
                    url=postgres_url,
                    table=table_name,
                    mode="append",
                    properties=postgres_properties
                )
            print(f"Batch {batch_id}: Written {batch_df.count()} records to {table_name}")
        else:
            print(f"Batch {batch_id}: No records to write to {table_name}")
    except Exception as e:
        print(f"Error writing batch {batch_id} to PostgreSQL {table_name}: {str(e)}")
        raise


def process_attribution_batch(batch_df, batch_id):
    """
    Process attribution for a micro-batch.
    This function applies first-click attribution logic using Window functions,
    which is allowed on batch DataFrames (not streaming DataFrames).
    """
    try:
        if batch_df.count() == 0:
            print(f"Batch {batch_id}: No records to process for attribution")
            return
        
        # Apply window function to get the first (earliest) click for each checkout
        # This works here because batch_df is a regular DataFrame, not a streaming one
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
        
        # Calculate attribution window
        final_df = attributed_df.withColumn(
            "attribution_window_seconds",
            unix_timestamp(col("checkout_timestamp")) - unix_timestamp(col("first_click_timestamp"))
        )
        
        # Write to PostgreSQL
        write_to_postgres(final_df, batch_id, "attributed_checkouts")
        
    except Exception as e:
        print(f"Error processing attribution batch {batch_id}: {str(e)}")
        raise


# Read streams
print("Reading Kinesis streams...")
clicks_df = read_kinesis_stream(args['CLICKS_STREAM_NAME'], click_schema)
checkouts_df = read_kinesis_stream(args['CHECKOUTS_STREAM_NAME'], checkout_schema)

# Add watermarks for late data handling (5 minutes)
clicks_with_watermark = clicks_df.withWatermark("event_timestamp", "5 minutes")
checkouts_with_watermark = checkouts_df.withWatermark("event_timestamp", "5 minutes")

# Perform stream-stream join
# Join checkouts with clicks that occurred within 1 hour before the checkout
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

# Write attributed clicks to PostgreSQL using foreachBatch
# The attribution logic (window function) is applied inside process_attribution_batch
print("Starting streaming query to PostgreSQL...")
query = joined_df.writeStream \
    .foreachBatch(process_attribution_batch) \
    .option("checkpointLocation", f"{args['CHECKPOINT_LOCATION']}/attribution") \
    .outputMode("append") \
    .trigger(processingTime='30 seconds') \
    .start()

# Also write raw clicks and checkouts for analytics
clicks_query = clicks_df \
    .select(
        col("event_id"),
        col("user_id"),
        col("product_id"),
        col("product_category"),
        col("referrer"),
        col("device_type"),
        col("event_timestamp")
    ) \
    .writeStream \
    .foreachBatch(lambda df, batch_id: write_to_postgres(df, batch_id, "raw_clicks")) \
    .option("checkpointLocation", f"{args['CHECKPOINT_LOCATION']}/clicks") \
    .outputMode("append") \
    .trigger(processingTime='30 seconds') \
    .start()

checkouts_query = checkouts_df \
    .select(
        col("event_id"),
        col("user_id"),
        col("total_amount"),
        col("payment_method"),
        col("event_timestamp")
    ) \
    .writeStream \
    .foreachBatch(lambda df, batch_id: write_to_postgres(df, batch_id, "raw_checkouts")) \
    .option("checkpointLocation", f"{args['CHECKPOINT_LOCATION']}/checkouts") \
    .outputMode("append") \
    .trigger(processingTime='30 seconds') \
    .start()

# Wait for all queries to terminate
print("Streaming job is running. Waiting for termination...")
query.awaitTermination()
clicks_query.awaitTermination()
checkouts_query.awaitTermination()

job.commit()