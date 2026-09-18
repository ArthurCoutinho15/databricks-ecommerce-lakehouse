# Naming Conventions & Materialization Defaults

## File / model naming

| Layer | Prefix | Pattern | Example |
|---|---|---|---|
| Staging | `stg_` | `stg_<source>__<entity>.sql` | `stg_stripe__payments.sql` |
| Intermediate | `int_` | `int_<entity>__<verb_phrase>.sql` | `int_orders__joined_with_refunds.sql` |
| Dimension | `dim_` | `dim_<entity>.sql` | `dim_customers.sql` |
| Fact | `fct_` | `fct_<entity>.sql` | `fct_orders.sql` |
| Snapshot | (none, own folder) | `<entity>_snapshot.sql` | `customers_snapshot.sql` |

- Use the plural form for dimensions and facts (`dim_customers`, not `dim_customer`) — one exception is fine if the business consistently uses singular language, but be consistent within the project.
- Double underscore (`__`) separates the source/entity from the description; single underscore joins words within a segment.
- Domain-based subfolders under `marts/` (e.g. `marts/finance/`, `marts/marketing/`) rather than one flat folder — group by who consumes the mart, not by source system.

## Column naming

- Primary/surrogate keys: `<entity>_key` (e.g. `customer_key`) — reserve `_id` for natural/source-system identifiers (e.g. `customer_id`, `stripe_customer_id`).
- Foreign keys in fact tables: `<dimension>_key`, matching the referenced dimension's surrogate key name exactly.
- Booleans: `is_` / `has_` prefix (`is_active`, `has_subscription`).
- Timestamps: `_at` suffix in UTC (`created_at`, `shipped_at`); dates: `_date` suffix (`order_date`).
- Amounts: suffix with the unit where ambiguity is possible (`amount_usd`, `weight_kg`).
- SCD2 audit columns (from dbt snapshots, don't rename these): `dbt_scd_id`, `dbt_updated_at`, `dbt_valid_from`, `dbt_valid_to`.

## Materialization defaults

| Layer | Default materialization | When to deviate |
|---|---|---|
| Staging | `view` | Very large source with expensive casts queried by many downstream models → `ephemeral` only if used once; otherwise leave as view |
| Intermediate | `ephemeral` or `view` | `table` only if the same intermediate model is expensive and reused by several marts |
| Dimensions | `table` | `incremental` only for very large, append-mostly dimensions (rare) |
| Facts (transaction) | `incremental` | `table` (full refresh) acceptable while data volume is small (<a few million rows) |
| Facts (periodic snapshot) | `incremental`, partitioned/clustered by period | — |
| Facts (accumulating snapshot) | `table` or `incremental` with `merge` strategy | — |

Set layer-wide defaults in `dbt_project.yml` under `models:` config blocks rather than repeating `{{ config(...) }}` in every file:

```yaml
models:
  your_project:
    staging:
      +materialized: view
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
      finance:
        fct_orders:
          +materialized: incremental
          +incremental_strategy: insert_overwrite
```
