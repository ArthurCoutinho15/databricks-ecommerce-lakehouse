{{
    config(
        materialized='table'
    )
}}

with order_payments as (
    select *
    from {{ source('silver', 'order_payments') }}
),

orders as (
    select *
    from {{ source('silver', 'orders') }}
),

customers as (
    select *
    from {{ source('silver', 'customers') }}
),

resolved as (
    select
        op.order_id,
        op.payment_sequential,
        op.payment_type,
        op.payment_value,
        op.payment_installments,
        c.customer_unique_id,
        ord.order_purchase_timestamp
    from order_payments as op
    left join orders as ord on op.order_id = ord.order_id
    left join customers as c on ord.customer_id = c.customer_id
),

final as (
    select
        r.order_id,
        r.payment_sequential,
        r.payment_type,
        dc.sk_customer,
        d.date_day as sk_date,
        r.payment_value,
        r.payment_installments
    from resolved as r
    left join {{ ref('dim_customer') }} as dc on r.customer_unique_id = dc.customer_unique_id
    left join {{ ref('dim_date') }} as d on cast(r.order_purchase_timestamp as date) = d.date_day
)

select * from final
