import sys
from pathlib import Path

sys.path.insert(0, str(Path(sys.argv[0]).resolve().parents[3]))

from pyspark.sql import SparkSession

from src.pipelines.landing_to_bronze import LandingToBronze

spark = SparkSession.builder.getOrCreate()

class BronzeOrdemItems:
    
    def run(self):
        l2b = LandingToBronze(
            spark,
            source_path="/Volumes/e_commerce/landing/landing",
            checkpoint_path="/Volumes/e_commerce/system/checkpoints/order_items",
            catalog="e_commerce",
            schema="bronze",
            table="order_items"
        )
        
        l2b.run(file_name="olist_order_items_dataset", file_format="csv")
        
if __name__ == "__main__":
    BronzeOrdemItems().run()