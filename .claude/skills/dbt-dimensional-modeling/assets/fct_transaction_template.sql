-- marts/<domain>/fct_<entity>.sql
-- Transaction fact: one row per event. Append-only, incremental on a watermark.

{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={'field': '<event_date_col>', 'data_type': 'date'},
        on_schema_change='append_new_columns',
    )
}}

with source as (
    select * from {{ ref('stg_<source>__<entity>') }}
    {% if is_incremental() %}
    where <event_date_col> >= (select max(<event_date_col>) from {{ this }})
    {% endif %}
),

final as (
    select
        s.<entity>_id,
        s.<event_date_col>,

        -- dimension foreign keys (surrogate keys, not natural keys)
        coalesce(dc.customer_key, '-1') as customer_key,
        coalesce(dp.product_key, '-1')  as product_key,

        -- additive facts
        s.quantity,
        s.amount

    from source s
    left join {{ ref('dim_customers') }} dc
        on s.customer_id = dc.customer_id
        and s.<event_date_col> >= dc.valid_from and s.<event_date_col> < dc.valid_to
    left join {{ ref('dim_products') }} dp
        on s.product_id = dp.product_id
)

select * from final
