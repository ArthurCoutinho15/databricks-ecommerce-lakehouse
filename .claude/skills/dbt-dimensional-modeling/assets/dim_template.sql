-- marts/<domain>/dim_<entity>.sql
-- Type 1 dimension (no history tracked). For SCD2, see dim_scd2_snapshot.sql instead.

with source as (
    select * from {{ ref('stg_<source>__<entity>') }}
),

enriched as (
    select
        {{ dbt_utils.generate_surrogate_key(['<entity>_id']) }} as <entity>_key,
        <entity>_id,
        -- denormalized descriptive attributes go here
        <entity>_name,
        <entity>_category
    from source
),

final as (
    select * from enriched

    union all

    -- Unknown member row for orphaned foreign keys in facts
    select
        '-1' as <entity>_key,
        '-1' as <entity>_id,
        'Unknown' as <entity>_name,
        'Unknown' as <entity>_category
)

select * from final
