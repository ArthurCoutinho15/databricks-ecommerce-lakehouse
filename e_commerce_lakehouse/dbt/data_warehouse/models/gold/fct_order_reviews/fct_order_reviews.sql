{{
    config(
        materialized='table'
    )
}}

with order_reviews as (
    select *
    from {{ source('silver', 'order_reviews') }}
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
        rev.review_id,
        rev.order_id,
        rev.review_score,
        rev.review_comment_message,
        rev.review_creation_date,
        c.customer_unique_id
    from order_reviews as rev
    left join orders as ord on rev.order_id = ord.order_id
    left join customers as c on ord.customer_id = c.customer_id
),

final as (
    select
        r.review_id,
        r.order_id,
        dc.sk_customer,
        dd.date_day as sk_date,
        r.review_score,
        r.review_comment_message,
        r.review_creation_date
    from resolved as r
    left join {{ ref('dim_customer') }} as dc on r.customer_unique_id = dc.customer_unique_id
    left join {{ ref('dim_date') }} as dd on cast(r.review_creation_date as date) = dd.date_day
)

select *
from final
