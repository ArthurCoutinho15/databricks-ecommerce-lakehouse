-- staging/<source>/stg_<source>__<entity>.sql
-- One model per source table. Light cleaning only: rename, cast, basic reshape.
-- No joins across sources here.

with source as (
    select * from {{ source('<source_name>', '<table_name>') }}
),

renamed as (
    select
        -- ids
        id                      as <entity>_id,

        -- foreign keys
        customer_id             as customer_id,

        -- descriptive attributes
        status                  as <entity>_status,

        -- numeric measures
        amount::numeric         as amount,

        -- timestamps (cast to a consistent type/timezone)
        created_at::timestamp   as created_at,
        updated_at::timestamp   as updated_at

    from source
)

select * from renamed
