from pyspark import pipelines as dp
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()


@dp.table(name="products")
@dp.expect_or_drop(
    "product_id_not_null",
    "product_id IS NOT NULL"
)

@dp.expect(
    "product_category_name_not_null",
    "product_category_name IS NOT NULL"
)

@dp.expect_or_drop(
    "weight_valid",
    "product_weight_g IS NULL OR product_weight_g > 0"
)

@dp.expect_or_drop(
    "length_valid",
    "product_length_cm IS NULL OR product_length_cm > 0"
)

@dp.expect_or_drop(
    "height_valid",
    "product_height_cm IS NULL OR product_height_cm > 0"
)

@dp.expect_or_drop(
    "width_valid",
    "product_width_cm IS NULL OR product_width_cm > 0"
)
def products():
    return spark.readStream.table("e_commerce.bronze.products")
