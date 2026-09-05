from pyspark.sql import SparkSession

from src.pipelines.landing_to_bronze import LandingToBronze

spark = SparkSession.builder.getOrCreate()

class BronzeProducts:
    
    def run(self):
        l2b = LandingToBronze(
            spark,
            source_path="/Volumes/e_commerce/landing/landing",
            checkpoint_path="/Volumes/e_commerce/system/checkpoints/products",
            catalog="e_commerce",
            schema="bronze",
            table="products"
        )
        
        l2b.run(file_name="olist_products_dataset", file_format="csv")
        
if __name__ == "__main__":
    BronzeProducts().run()