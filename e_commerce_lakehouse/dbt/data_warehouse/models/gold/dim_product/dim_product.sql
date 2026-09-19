{{
    config(
        materialized='table'
    )
}}

with products as (
    select *
    from {{ source('silver', 'products') }}
),

products_category as (
    select *
    from {{ source('silver', 'product_category_name_translation') }}
),

final as (
    select 
        {{ dbt_utils.generate_surrogate_key(['product_id'])}} as sk_product,
        p.product_id,
        p.product_category_name as category_name,
        pc.product_category_name_english as english_category_name,
        p.product_weight_g,
        p.product_length_cm,
        p.product_height_cm,
        p.product_width_cm
    from products as p 
    left join products_category as pc on p.product_category_name = pc.product_category_name
)

select *
from final
