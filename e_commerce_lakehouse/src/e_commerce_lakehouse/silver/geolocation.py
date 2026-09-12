from pyspark import pipelines as dp
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()


@dp.table(name="geolocation")
def geolocation():
    return spark.readStream.table("e_commerce.bronze.geolocation")
