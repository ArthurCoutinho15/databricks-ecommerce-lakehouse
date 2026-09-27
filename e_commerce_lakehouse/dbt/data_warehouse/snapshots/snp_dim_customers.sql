{% snapshot snap_dim_customers %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_unique_id',
        strategy='check',
        check_cols=['customer_city', 'customer_state'],
    )
}}

-- Um mesmo customer_unique_id pode aparecer em vários pedidos com
-- customer_id diferentes (cliente recorrente). O snapshot precisa de
-- exatamente 1 linha por unique_key por execução, senão o MERGE não sabe
-- qual das linhas usar pra atualizar o mesmo alvo (erro
-- DELTA_MULTIPLE_SOURCE_ROW_MATCHING_TARGET_ROW_IN_MERGE). Aplicamos aqui a
-- mesma regra de "pedido mais recente" que a dim_customer usa.
with ranked as (

    select
        *,
        row_number() over (
            partition by customer_unique_id
            order by customer_id desc
        ) as rn

    from {{ source('silver', 'customers') }}

)

select
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
from ranked
where rn = 1

{% endsnapshot %}
