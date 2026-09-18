-- marts/<domain>/fct_<entity>_<period>.sql
-- Periodic snapshot fact: one row per entity per period, even with no change.

{{
    config(
        materialized='incremental',
        incremental_strategy='insert_overwrite',
        partition_by={'field': 'snapshot_period', 'data_type': 'date'},
    )
}}

with source as (
    select * from {{ ref('stg_<source>__<entity>') }}
    {% if is_incremental() %}
    where <activity_date_col> >= (select max(snapshot_period) from {{ this }})
    {% endif %}
),

periods as (
    select
        <entity>_id,
        date_trunc('month', <activity_date_col>) as snapshot_period,
        -- example semi-additive measure: value as of period end
        last_value(<measure_col>) over (
            partition by <entity>_id, date_trunc('month', <activity_date_col>)
            order by <activity_date_col>
            rows between unbounded preceding and unbounded following
        ) as <measure_col>_period_end
    from source
)

select distinct
    coalesce(d.<entity>_key, '-1') as <entity>_key,
    p.snapshot_period,
    p.<measure_col>_period_end
from periods p
left join {{ ref('dim_<entity>') }} d on p.<entity>_id = d.<entity>_id
