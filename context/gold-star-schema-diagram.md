# Diagrama dimensional — Gold Layer (Star Schema)

> Acompanha [gold-star-schema-plan.md](gold-star-schema-plan.md). Este diagrama é o
> "mapa" do modelo; a checklist é o passo a passo de construção.

## Visão geral

```mermaid
erDiagram
    dim_customer ||--o{ fct_order_items : "sk_customer"
    dim_product  ||--o{ fct_order_items : "sk_product"
    dim_seller   ||--o{ fct_order_items : "sk_seller"
    dim_date     ||--o{ fct_order_items : "sk_date (order_purchase)"

    dim_customer ||--o{ fct_order_payments : "sk_customer"
    dim_date     ||--o{ fct_order_payments : "sk_date (order_purchase)"

    dim_customer ||--o{ fct_order_reviews : "sk_customer"
    dim_date     ||--o{ fct_order_reviews : "sk_date (review_creation)"

    dim_customer {
        string sk_customer PK
        string customer_unique_id "natural key"
        string zip_code_prefix
        string city
        string state
        float lat "de int_geolocation"
        float lng "de int_geolocation"
    }

    dim_product {
        string sk_product PK
        string product_id "natural key"
        string product_category_name
        string product_category_name_english
        float product_weight_g
        float product_length_cm
        float product_height_cm
        float product_width_cm
    }

    dim_seller {
        string sk_seller PK
        string seller_id "natural key"
        string zip_code_prefix
        string city
        string state
        float lat "de int_geolocation"
        float lng "de int_geolocation"
    }

    dim_date {
        date date_day PK
        int year
        int month
        string month_name
        int day_of_week
        boolean is_weekend
    }

    fct_order_items {
        string order_id "degenerada"
        int order_item_id "degenerada"
        string order_status "degenerada"
        string sk_customer FK
        string sk_product FK
        string sk_seller FK
        date sk_date FK
        decimal price "medida"
        decimal freight_value "medida"
    }

    fct_order_payments {
        string order_id "degenerada"
        int payment_sequential "degenerada"
        string payment_type "degenerada"
        string sk_customer FK
        date sk_date FK
        decimal payment_value "medida"
        int payment_installments "medida"
    }

    fct_order_reviews {
        string review_id "degenerada"
        string order_id "degenerada"
        string sk_customer FK
        date sk_date FK
        int review_score "medida"
        string review_comment_message "descritiva"
    }
```

## Notas de leitura do diagrama

- **`int_geolocation` não aparece como entidade própria** — ele é um modelo
  intermediário (zip_code_prefix → lat/lng médios) usado só para *enriquecer*
  `dim_customer` e `dim_seller` via join na hora de construir essas dimensões. Ele não é
  joinado diretamente pelas fact tables, por isso não tem uma linha de relacionamento no
  diagrama.
- **Três fact tables, grãos diferentes**: `fct_order_items` (1 linha = 1 item de pedido),
  `fct_order_payments` (1 linha = 1 pagamento de um pedido) e `fct_order_reviews` (1 linha
  = 1 avaliação). Elas não se juntam entre si diretamente — cada uma se conecta às
  dimensões compartilhadas (`dim_customer`, `dim_date`) de forma independente. Isso é
  esperado num modelo com múltiplos processos de negócio (fan-out trap se tentar juntar
  as três facts numa query só sem cuidado).
- **Campos "degenerada"** (`order_id`, `payment_sequential`, `review_id` etc.) ficam
  direto na fact table, sem dimensão própria — servem para agrupar/filtrar, mas não têm
  atributos descritivos adicionais que justifiquem uma dimensão separada.
- **`dim_date`** é referenciada por todas as facts, mas cada uma usa uma data de negócio
  diferente (compra, criação da review) — por isso o relacionamento tem um rótulo
  diferente em cada linha, mesmo sendo sempre a mesma dimensão fisicamente.

## Ordem sugerida de construção (bate com a checklist do plano)

```mermaid
flowchart LR
    A[dim_date] --> F1[fct_order_items]
    B[int_geolocation] --> C[dim_customer]
    B --> D[dim_seller]
    E[dim_product] --> F1
    C --> F1
    D --> F1
    A --> F2[fct_order_payments]
    C --> F2
    A --> F3[fct_order_reviews]
    C --> F3
```

Dimensões sem dependência (`dim_date`, `int_geolocation`, `dim_product`) podem ser
construídas em paralelo. `dim_customer`/`dim_seller` dependem de `int_geolocation`. As
três fact tables só fazem sentido depois que as dimensões que elas referenciam já
existirem.
