-- snapshots/<entity>_snapshot.sql
-- Run with `dbt snapshot`. Lives in snapshots/, not models/.

{% snapshot <entity>_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='<entity>_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True,
    )
}}

select
    <entity>_id,
    <tracked_attribute_1>,
    <tracked_attribute_2>,
    updated_at
from {{ source('<source_name>', '<table_name>') }}

{% endsnapshot %}


-- Then, in marts/<domain>/dim_<entity>.sql, build the dimension on top of it:
--
-- with snapshot as (
--     select * from {{ ref('<entity>_snapshot') }}
-- )
-- select
--     {{ dbt_utils.generate_surrogate_key(['<entity>_id', 'dbt_valid_from']) }} as <entity>_key,
--     <entity>_id,
--     <tracked_attribute_1>,
--     <tracked_attribute_2>,
--     dbt_valid_from as valid_from,
--     coalesce(dbt_valid_to, '9999-12-31') as valid_to,
--     (dbt_valid_to is null) as is_current
-- from snapshot
