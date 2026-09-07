from typing import Optional

from pyspark.sql import DataFrame, SparkSession
from pyspark.sql.types import StructType


class BronzeToSilver:
    def __init__(
            self, 
            spark: SparkSession, 
            source_table: str, 
            checkpoint_path: str,
            catalog: str, 
            schema: str, 
            table: str
        ):
        self.spark: SparkSession = spark
        self.source_table = source_table
        self.checkpoint = checkpoint_path
        self.catalog = catalog
        self.schema = schema
        self.table = table

    def read_data(self) -> DataFrame:
        df = (
            self.spark.readStream
            .format("delta")
            .table(f"{self.source_table}")
        )
        
        return df
    
    def save_data(self, df: DataFrame) -> None:
        query = (
            df.writeStream
            .format("delta")
            .option(
                "checkpointLocation",
                f"{self.checkpoint}"
            )
            .trigger(availableNow=True)
            .toTable(f"{self.catalog}.{self.schema}.{self.table}")
        )
        
        query.awaitTermination()
        