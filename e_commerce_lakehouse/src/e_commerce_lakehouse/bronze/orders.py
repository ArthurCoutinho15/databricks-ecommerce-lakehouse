from pyspark.sql import SparkSession

from src.pipelines.landing_to_bronze import LandingToBronze

spark = SparkSession.builder.getOrCreate()

class BronzeOrders:
    
    def run(self):
        l2b = LandingToBronze(
            spark,
            source_path="/Volumes/e_commerce/landing/landing",
            checkpoint_path="/Volumes/e_commerce/system/checkpoints/orders",
            catalog="e_commerce",
            schema="bronze",
            table="orders"
        )
        
        l2b.run(file_name="olist_orders_dataset", file_format="csv")
        
if __name__ == "__main__":
    BronzeOrders().run()