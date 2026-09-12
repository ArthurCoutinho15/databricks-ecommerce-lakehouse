from pyspark import pipelines as dp
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()


@dp.table(name="customers")
@dp.expect_or_drop("customer_id_is_not_null", "customer_id IS NOT NULL")
@dp.expect_or_drop(
    "zip_code_valid",
    "customer_zip_code_prefix BETWEEN 0 AND 99999"
)
def customers():
    return spark.readStream.table("e_commerce.bronze.customers")
