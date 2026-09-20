{% snapshot snap_dim_customers %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_unique_id',
        strategy='check',
        check_cols=['customer_city', 'customer_state'],
    )
}}

select
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
from {{ source('silver', 'customers') }}

{% endsnapshot %}
