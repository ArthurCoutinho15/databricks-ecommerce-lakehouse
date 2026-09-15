# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository layout

The Databricks Asset Bundle project lives entirely under `e_commerce_lakehouse/` — run all commands below from that directory, not the repo root.

## Commands

Dependencies are managed with `uv` (not pip directly).

```bash
# Install dependencies
uv sync --dev

# Run all tests (requires Databricks Connect auth; see below)
uv run pytest

# Run a single test
uv run pytest tests/sample_taxis_test.py::test_find_all_taxis

# Lint (line-length 120, configured in pyproject.toml)
uv run ruff check .
uv run ruff format .

# Authenticate to the Databricks workspace (needed for tests and bundle commands)
databricks configure

# Validate / deploy the bundle
databricks bundle validate --target dev
databricks bundle deploy --target dev      # dev is the default target
databricks bundle deploy --target prod

# Run a job or pipeline defined in the bundle
databricks bundle run <resource-key> --target dev
```

Tests use `databricks.connect.DatabricksSession` (see `tests/conftest.py`), so they execute against a real Databricks workspace/serverless compute, not a local Spark session — `databricks configure` must succeed first, and `pytest` will fall back to serverless compute if no cluster is configured.

dbt lives in `e_commerce_lakehouse/dbt/data_warehouse/` and targets a SQL Warehouse (`dbt-databricks`); it deploys as part of the bundle via the `e_commerce_gold_dbt_job` job (`dbt deps && dbt run --select <model>`), not run standalone in most workflows.

## Architecture

This is a medallion-architecture lakehouse (landing → bronze → silver → gold) for the Olist e-commerce dataset, deployed as one Databricks Asset Bundle (`databricks.yml`). Catalog is `e_commerce`; schemas are `landing`, `system` (checkpoints), `bronze`, `silver`, `gold`, `snapshots` (declared in `resources/infra/schemas.yml` / `volumes.yml`).

Each layer transition uses a different execution model, and each is wired up as a separate Databricks job/pipeline, chained together by `e_commerce_orchestrator_job` (`resources/jobs/e_commerce_orchestrator_job.job.yml`): `bronze-spark` (run_job_task) → `silver-sdp` (pipeline_task) → `gold-dbt` (run_job_task). Note the orchestrator currently references target `job_id`/`pipeline_id` values as hardcoded literals rather than bundle resource references (`${resources.jobs...id}`) — keep that in mind if resources are redeployed to a new workspace/target, since the hardcoded IDs won't follow.

**Landing → Bronze** (`e_commerce_etl_job.job.yml`): one Spark Python task per source table (`src/e_commerce_lakehouse/bronze/*.py`), each instantiating the shared `LandingToBronze` class (`src/pipelines/landing_to_bronze.py`). This uses Auto Loader (`cloudFiles`) structured streaming with `trigger(availableNow=True)`, reading CSVs from the `landing` volume and writing Delta tables into `bronze.*`, with per-table checkpoint paths under the `system.checkpoints` volume.

**Bronze → Silver** (`e_commerce_lakehouse_etl.pipeline.yml`): a single serverless Lakeflow Declarative Pipeline (`pyspark.pipelines`, decorator-based: `@dp.table`, `@dp.expect_or_drop`) with `root_path` pointing at `src/e_commerce_lakehouse/silver/`. Each file (e.g. `silver/customers.py`, `silver/orders.py`) defines one streaming table read from the corresponding `bronze.*` table, with data-quality expectations declared inline (dropped rows on violation). `src/pipelines/bronze_to_silver.py` (a `BronzeToSilver` helper class, structured-streaming based) is legacy/unused now that silver runs through the declarative pipeline — don't assume it's on the execution path.

**Silver → Gold** (`e_commerce_gold_dbt_job.job.yml` + `dbt/data_warehouse/`): dbt models build the star schema on top of `silver.*` sources (declared in `models/gold/source.yml`). Currently only `dim_customer` exists (SCD1 dedup by `customer_unique_id`, surrogate key via `dbt_utils.generate_surrogate_key`); a matching SCD2 snapshot (`snapshots/snp_dim_customers.sql`, strategy `check` on city/state) preserves history separately in the `snapshots` schema. The fact table and remaining dimensions (products, sellers, orders, payments, reviews, geolocation) are not yet built even though their silver sources are already declared — expect to add new `models/gold/<name>/` folders following the `dim_customer` pattern when extending the star schema.

`src/e_commerce_lakehouse/main.py` and `tests/sample_taxis_test.py` still reference an `e_commerce_lakehouse.taxis` module that doesn't exist in this repo — leftover from the `default-python` bundle template. Don't use `main.py` as a reference for how jobs are actually wired; the real entry points are the per-table scripts in `bronze/` and `silver/`.
