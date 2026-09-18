# Fact Table Patterns

## 1. Transaction fact (most common)

One row per discrete business event. Never revisited or updated after load (append-only in the real world, e.g. an order line item).

```sql
-- marts/sales/fct_order_lines.sql
{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={'field': 'order_date', 'data_type': 'date'},
        on_schema_change='append_new_columns',
    )
}}

with order_lines as (
    select * from {{ ref('stg_app__order_lines') }}
    {% if is_incremental() %}
    where order_date >= (select max(order_date) from {{ this }})
    {% endif %}
),

final as (
    select
        ol.order_line_id,
        ol.order_date,
        dc.customer_key,
        dp.product_key,
        dd.date_key,
        ol.quantity,
        ol.unit_price,
        ol.quantity * ol.unit_price as gross_amount,
        ol.discount_amount,
        (ol.quantity * ol.unit_price) - ol.discount_amount as net_amount
    from order_lines ol
    left join {{ ref('dim_customers') }} dc
        on ol.customer_id = dc.customer_id
        and ol.order_date >= dc.valid_from and ol.order_date < dc.valid_to
    left join {{ ref('dim_products') }} dp on ol.product_id = dp.product_id
    left join {{ ref('dim_dates') }} dd on ol.order_date = dd.date_day
)

select * from final
```

Grain check for this table: `order_line_id` must be unique. Test it with `dbt_utils.unique_combination_of_columns` or a plain `unique` test.

## 2. Periodic snapshot fact

One row per entity per fixed period, even if nothing changed — used for things like "balance at end of month" or "daily active subscriber count." Volume is predictable (entities × periods), unlike transaction facts.

```sql
-- marts/finance/fct_account_balances_monthly.sql
{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={'field': 'snapshot_month', 'data_type': 'date'},
    )
}}

with balances as (
    select
        account_id,
        date_trunc('month', balance_date) as snapshot_month,
        -- last balance recorded in the month
        last_value(balance) over (
            partition by account_id, date_trunc('month', balance_date)
            order by balance_date
            rows between unbounded preceding and unbounded following
        ) as ending_balance
    from {{ ref('stg_app__account_balances') }}
    {% if is_incremental() %}
    where balance_date >= (select max(snapshot_month) from {{ this }})
    {% endif %}
)

select distinct
    da.account_key,
    snapshot_month,
    ending_balance
from balances b
left join {{ ref('dim_accounts') }} da on b.account_id = da.account_id
```

Semi-additive warning: `ending_balance` sums correctly across accounts but NOT across months (summing 12 month-end balances doesn't mean anything) — document this explicitly in the column description.

## 3. Accumulating snapshot fact

One row per process instance; the row is **updated in place** as the process moves through milestones. Requires a `merge`/upsert strategy, not append.

```sql
-- marts/logistics/fct_order_fulfillment.sql
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='order_id',
    )
}}

select
    o.order_id,
    dc.customer_key,
    o.placed_at,
    o.paid_at,
    o.shipped_at,
    o.delivered_at,
    datediff('hour', o.placed_at, o.paid_at)     as hours_to_payment,
    datediff('hour', o.paid_at, o.shipped_at)     as hours_to_ship,
    datediff('hour', o.shipped_at, o.delivered_at) as hours_to_deliver,
    case
        when o.delivered_at is not null then 'delivered'
        when o.shipped_at   is not null then 'shipped'
        when o.paid_at      is not null then 'paid'
        else 'placed'
    end as current_stage
from {{ ref('stg_app__orders') }} o
left join {{ ref('dim_customers') }} dc on o.customer_id = dc.customer_id
```

Each milestone timestamp starts null and gets filled in on a later run once that stage happens — the `merge` strategy on `unique_key='order_id'` lets dbt update the existing row rather than inserting a duplicate.

## The "Unknown member" pattern

Every dimension should have a row for foreign keys in fact tables that don't resolve to a real member (late-arriving dimension, bad data, deliberate "N/A"). Add it with a `union all`:

```sql
-- at the end of dim_customers.sql
select * from customers_final

union all

select
    '-1' as customer_key,
    '-1' as customer_id,
    'Unknown' as email,
    'Unknown' as customer_tier,
    null as sales_rep_id,
    cast('1900-01-01' as timestamp) as valid_from,
    cast('9999-12-31' as timestamp) as valid_to,
    true as is_current
```

Then use `left join ... coalesce(dc.customer_key, '-1')` — or better, resolve unmatched keys to `'-1'` in the fact's `select` — so fact rows never carry a null foreign key, which silently breaks `inner join`-based BI queries.
