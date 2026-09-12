from pyspark import pipelines as dp
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()


@dp.table(name="product_category_name_translation")
def product_category_name_translation():
    return spark.readStream.table("e_commerce.bronze.product_category_name_translation")
