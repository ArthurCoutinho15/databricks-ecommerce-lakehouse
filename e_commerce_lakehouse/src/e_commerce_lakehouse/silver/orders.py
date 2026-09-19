from pyspark import pipelines as dp
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()


@dp.table(name="orders")
@dp.expect_or_drop(
    "order_id_not_null",
    "order_id IS NOT NULL"
)
@dp.expect_or_drop(
    "customer_id_not_null",
    "customer_id IS NOT NULL"
)
@dp.expect_or_drop(
    "order_status_valid",
    """
    order_status IN (
        'delivered',
        'shipped',
        'canceled',
        'unavailable',
        'invoiced',
        'processing',
        'created',
        'approved'
    )
    """
)
def orders():
    df = (
        spark.readStream.table("e_commerce.bronze.orders")
        .withColumn("order_purchase_timestamp", f.col("order_purchase_timestamp").cast(t.TimestampType()))
        .withColumn("order_approved_at", f.col("order_approved_at").cast(t.TimestampType()))
        .withColumn("order_delivered_carrier_date", f.col("order_delivered_carrier_date").cast(t.TimestampType()))
        .withColumn("order_delivered_customer_date", f.col("order_delivered_customer_date").cast(t.TimestampType()))
        .withColumn("order_estimated_delivery_date", f.col("order_estimated_delivery_date").cast(t.TimestampType()))
    )
    return df


