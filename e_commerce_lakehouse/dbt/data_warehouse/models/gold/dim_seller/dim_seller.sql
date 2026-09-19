{{
    config(
        materialized='table'
    )
}}


with source as (
    select *
    from {{ source('silver', 'sellers') }}
),

deduped as (
    select 
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state
    from (
        select *, row_number() over(partition by seller_id order by seller_id asc) as rn
        from source
    )
    where rn = 1
),

lat_long_enrichment as (
    select 
        sl.*,
        geo.lat as latitude,
        geo.lng as longitude
    from deduped as sl 
    left join {{ ref('int_geolocation') }} as geo on sl.seller_zip_code_prefix = geo.zip_code_prefix
),

final as (
    select 
        {{ dbt_utils.generate_surrogate_key(['seller_id']) }} as sk_seller,
        *
    from lat_long_enrichment

)

select *
from final
