# Slowly Changing Dimensions (Type 2) with dbt Snapshots

## Why snapshots, not a hand-rolled model

A `dim_` model re-runs and overwrites itself every time — it has no memory of what a row looked like yesterday. dbt **snapshots** solve this: they run against a mutable source table on a schedule (or before each run) and append a new row every time a tracked column changes, while closing out the old row. This gives you history without writing any diffing logic yourself.

## Snapshot definition

```sql
-- snapshots/customers_snapshot.sql
{% snapshot customers_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='customer_id',
      strategy='timestamp',
      updated_at='updated_at',
      invalidate_hard_deletes=True,
    )
}}

select
    customer_id,
    email,
    customer_tier,
    sales_rep_id,
    updated_at
from {{ source('app', 'customers') }}

{% endsnapshot %}
```

- `strategy='timestamp'` + `updated_at` is preferred when the source has a reliable last-modified column. Use `strategy='check'` with `check_cols=['customer_tier', 'sales_rep_id']` (or `check_cols='all'`) when there's no trustworthy timestamp — dbt then diffs the listed columns row by row.
- `invalidate_hard_deletes=True` closes out (sets `dbt_valid_to`) rows that disappear from the source instead of leaving stale open records.
- Snapshots are **append-only** and live outside `models/` in their own `snapshots/` directory. Run them with `dbt snapshot`, on a schedule that matches how often you need to catch a change (hourly/daily are typical).

## Contract dbt snapshots give you

Every snapshot table gets these columns automatically — never rename or drop them:

| Column | Meaning |
|---|---|
| `dbt_scd_id` | Unique id for this specific version of the row |
| `dbt_updated_at` | When this version was captured |
| `dbt_valid_from` | Timestamp this version became active |
| `dbt_valid_to` | Timestamp this version was superseded; `null` = currently active |

## Building `dim_customers` on top of the snapshot

The snapshot itself is not the dimension — build a thin `dim_` model on top of it that generates the surrogate key and renames columns to your conventions:

```sql
-- marts/crm/dim_customers.sql
with snapshot as (
    select * from {{ ref('customers_snapshot') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['customer_id', 'dbt_valid_from']) }} as customer_key,
    customer_id,
    email,
    customer_tier,
    sales_rep_id,
    dbt_valid_from as valid_from,
    coalesce(dbt_valid_to, '9999-12-31') as valid_to,
    (dbt_valid_to is null) as is_current
from snapshot
```

- Surrogate key includes `dbt_valid_from` so each historical version gets its own unique `customer_key` — this is the key that fact tables should join to.
- `coalesce(..., '9999-12-31')` on `valid_to` avoids null-handling issues in downstream `BETWEEN` joins.
- Keep `is_current` for the common case of "give me the current attribute value" queries without a date join.

## Joining a fact to an SCD2 dimension "as of" the event time

This is the join pattern that makes SCD2 worth the complexity — it lets you attribute a historical fact to the dimension value that was true *at that time*, not today's value:

```sql
select
    o.order_id,
    o.order_date,
    dc.customer_key,
    dc.customer_tier   -- tier as of the order date, not today
from {{ ref('stg_app__orders') }} o
left join {{ ref('dim_customers') }} dc
    on o.customer_id = dc.customer_id
    and o.order_date >= dc.valid_from
    and o.order_date <  dc.valid_to
```

If you only ever need the *current* attribute value joined to historical facts, join on `dc.is_current = true` instead and skip the date range — but confirm this is actually what the business wants before defaulting to it, since it silently discards history.
