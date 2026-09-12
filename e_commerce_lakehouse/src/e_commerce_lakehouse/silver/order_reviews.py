from pyspark import pipelines as dp
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()


@dp.table(name="order_reviews")
def order_reviews():
    return spark.readStream.table("e_commerce.bronze.order_reviews")
