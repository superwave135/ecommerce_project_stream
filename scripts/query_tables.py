import sys
from pyspark.sql import SparkSession

# Initialize Spark
spark = SparkSession.builder \
    .appName("QueryTables") \
    .getOrCreate()

# CORRECT JDBC connection details
jdbc_url = "jdbc:postgresql://ecommerce-streaming-dev-postgres.c7asemuggn20.ap-southeast-1.rds.amazonaws.com:5432/ecommerce_analytics"
connection_properties = {
    "user": "dbadmin",
    "password": "#datageek135",
    "driver": "org.postgresql.Driver"
}

print("\n" + "="*80)
print("📊 TABLE STATISTICS")
print("="*80)

# Query each table
for table in ['events_clicks', 'events_checkouts', 'session_attribution']:
    try:
        df = spark.read.jdbc(jdbc_url, table, properties=connection_properties)
        count = df.count()
        print(f"\n✅ {table}: {count} records")
        
        if count > 0:
            print(f"\nSample records from {table}:")
            df.show(5, truncate=False)
    except Exception as e:
        print(f"\n❌ Error reading {table}: {str(e)}")

print("\n" + "="*80)