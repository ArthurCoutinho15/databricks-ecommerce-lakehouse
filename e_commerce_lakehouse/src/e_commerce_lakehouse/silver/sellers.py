import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from pyspark.sql import DataFrame, SparkSession

from src.pipelines.bronze_to_silver import BronzeToSilver

spark = SparkSession.builder.getOrCreate()


class SilverSellers:
    def run(self):
        b2s = BronzeToSilver(
            spark,
            source_table="e_commerce.bronze.sellers",
            checkpoint_path="/Volumes/e_commerce/system/checkpoints/silver/sellers",
            catalog="e_commerce",
            schema="silver",
            table="sellers",
        )
        df: DataFrame = b2s.read_data()

        b2s.save_data(df)


if __name__ == "__main__":
    SilverSellers().run()
