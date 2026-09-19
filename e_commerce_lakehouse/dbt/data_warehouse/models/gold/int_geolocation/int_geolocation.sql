{{
    config(
        materialized="table"
    )
}}


with source as (
    select *
    from {{ source('silver', 'geolocation') }}
),

aggregated as (
    select 
        geolocation_zip_code_prefix as zip_code_prefix,
        avg(geolocation_lat) as lat,
        avg(geolocation_lng) as lng,
        mode(geolocation_city) as city,
        mode(geolocation_state) as state
    from source
    group by 1

)

select *
from aggregated