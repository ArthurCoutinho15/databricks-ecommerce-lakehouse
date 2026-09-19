{{
    config(
        materialized='table'
    )
}}

with order_items as (
    select * from {{ source('silver', 'order_items') }}
),
orders as (
    select * from {{ source('silver', 'orders') }}
),
customers as (
    select * from {{ source('silver', 'customers') }}
),

resolved as (
    select
        oi.order_id,
        oi.order_item_id,
        oi.product_id,
        oi.seller_id,
        oi.price,
        oi.freight_value,
        o.order_status,
        o.order_purchase_timestamp,
        c.customer_unique_id
    from order_items as oi
    left join orders as o on oi.order_id = o.order_id
    left join customers as c on o.customer_id = c.customer_id
),

final as (
    select
        r.order_id,
        r.order_item_id,
        r.order_status,
        dc.sk_customer,
        dp.sk_product,
        ds.sk_seller,
        dd.date_day as sk_date,
        r.price,
        r.freight_value
    from resolved as r
    left join {{ ref('dim_customer') }} as dc on r.customer_unique_id = dc.customer_unique_id
    left join {{ ref('dim_product') }} as dp on r.product_id = dp.product_id
    left join {{ ref('dim_seller') }} as ds on r.seller_id = ds.seller_id
    left join {{ ref('dim_date') }} as dd on cast(r.order_purchase_timestamp as date) = dd.date_day
)

select * from final

