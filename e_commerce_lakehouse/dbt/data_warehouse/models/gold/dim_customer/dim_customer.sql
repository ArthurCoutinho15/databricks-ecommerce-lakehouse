{{
    config(
        materialized='table'
    )
}}

with customers as (

    select * from {{ source('silver', 'customers') }}

),

-- Um mesmo customer_unique_id pode aparecer em vários pedidos com
-- customer_id diferentes e, ocasionalmente, com cidade/estado distintos
-- (o cliente se mudou). Aqui pegamos o registro mais recente por cliente
-- para representar o estado "atual" na dimensão (abordagem SCD tipo 1).
-- Se quiser manter histórico (SCD tipo 2), veja o snapshot em
-- snapshots/snap_dim_cliente.sql.
ranked as (

    select
        *,
        row_number() over (
            partition by customer_unique_id
            order by customer_id desc
        ) as rn

    from customers

),

deduped as (

    select
        customer_unique_id,
        customer_zip_code_prefix as zip_code_prefix,
        customer_city as city,
        customer_state as state
    from ranked
    where rn = 1

),

final as (

    select
        {{ dbt_utils.generate_surrogate_key(['customer_unique_id']) }} as sk_cliente,
        customer_unique_id,
        zip_code_prefix,
        city,
        state

    from deduped

)

select * from final