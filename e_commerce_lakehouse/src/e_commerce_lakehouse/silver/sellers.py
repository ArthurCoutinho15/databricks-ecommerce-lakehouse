from pyspark import pipelines as dp
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()


@dp.table(name="sellers")
def sellers():
    return spark.readStream.table("e_commerce.bronze.sellers")
