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
    return spark.readStream.table("e_commerce.bronze.orders")
