from pyspark.sql import DataFrame, SparkSession


class LandingToBronze:
    def __init__(
        self,
        spark: SparkSession,
        source_path: str,
        checkpoint_path: str,
        catalog: str,
        schema: str,
        table: str,
    ):
        self.spark: SparkSession = spark
        self.source_path = source_path
        self.checkpoint_path = checkpoint_path
        self.catalog = catalog
        self.schema = schema
        self.table = table

    def read_data(self, file_name: str, file_format: str) -> DataFrame:
        reader = (
            self.spark.readStream.format("cloudFiles")
            .option("cloudFiles.format", f"{file_format}")
            .option("pathGlobFilter", f"{file_name}*.{file_format}")
            .option(
                "cloudFiles.schemaLocation",
                f"{self.checkpoint_path.rstrip('/')}/schema",
            )
        )

        if file_format == "csv":
            reader = reader.option("header", "true")

        return reader.load(self.source_path).selectExpr("*", "_metadata")

    def write_data(self, dataframe: DataFrame) -> None:
        query = (
            dataframe.writeStream.format("delta")
            .option("checkpointLocation", self.checkpoint_path)
            .option("mergeSchema", "true")
            .trigger(availableNow=True)
            .toTable(f"{self.catalog}.{self.schema}.{self.table}")
        )

        query.awaitTermination()

    def run(self, file_name: str, file_format: str) -> None:
        df = self.read_data(file_name, file_format)
        self.write_data(df)
