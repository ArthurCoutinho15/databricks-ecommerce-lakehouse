from pyspark import pipelines as dp
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()


@dp.table(name="order_payments")
def order_payments():
    return spark.readStream.table("e_commerce.bronze.order_payments")
