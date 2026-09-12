from pyspark import pipelines as dp
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()


@dp.table(name="order_items")
@dp.expect_or_drop(
    "price_is_valid", 
    "price IS NOT NULL AND price > 0"
)
def order_items():
    return spark.readStream.table("e_commerce.bronze.order_items")
