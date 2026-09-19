# Plano: evoluir a camada Gold para um Star Schema completo

> Checklist de acompanhamento manual. Marque `[x]` conforme for implementando.
> Peça ajuda pontual à Claude por fase quando precisar — não é pra ela implementar tudo de uma vez.

## Contexto

Hoje a camada gold (`e_commerce_lakehouse/dbt/data_warehouse/`) só tem `dim_customer`
(SCD1, com um snapshot `snp_dim_customers` para histórico SCD2 que **não está sendo
executado** pelo job — o job só roda `dbt run --select dim_customer`). Todas as fontes
silver necessárias já estão declaradas em `models/gold/source.yml` (customers, orders,
order_items, order_payments, order_reviews, products, sellers, geolocation,
product_category_name_translation), mas não há nenhum modelo consumindo a maioria delas.

Objetivo: modelar o processo de negócio "pedidos de e-commerce" como um star schema
completo (Kimball), usando a skill `dbt-dimensional-modeling` (`.claude/skills/`) como
guia de convenções, seguindo o padrão de pasta-por-modelo já usado em `dim_customer/`.

## Desenho dimensional

**Processo de negócio:** pedidos realizados na plataforma (Olist).
**Grão da fact principal:** uma linha por item de pedido (`order_id` + `order_item_id`).

| Modelo | Tipo | Grão | Chave natural | SCD |
|---|---|---|---|---|
| `dim_customer` | dimensão | 1 cliente | `customer_unique_id` | SCD1 (já existe) — enriquecer com lat/lng |
| `dim_product` | dimensão | 1 produto | `product_id` | SCD1 (novo) |
| `dim_seller` | dimensão | 1 vendedor | `seller_id` | SCD1 (novo) — enriquecer com lat/lng |
| `dim_date` | dimensão | 1 dia | `date_day` | calendário gerado |
| `fct_order_items` | fact transacional | 1 item de pedido | `order_id, order_item_id` | — |
| `fct_order_payments` | fact transacional | 1 pagamento de pedido | `order_id, payment_sequential` | — |
| `fct_order_reviews` | fact transacional | 1 avaliação | `review_id` | — |

### Decisões de design já tomadas

- **Geolocalização não vira dimensão própria.** `geolocation` é `zip_code_prefix →
  lat/lng/city/state`, com várias linhas por CEP. Em vez de virar dimensão separada ligada
  à fact (snowflake), é agregada (média de lat/lng por `zip_code_prefix`) num modelo
  intermediário `int_geolocation` e **denormalizada dentro de `dim_customer` e
  `dim_seller`**.
- **`order_status` e ids de pedido** entram como dimensões degeneradas direto em
  `fct_order_items` — não viram uma `dim_order_status` à parte (cardinalidade baixa, não
  compensa o modelo extra).
- **Pagamentos e reviews viram fact tables próprias**, não colunas em `fct_order_items`:
  um pedido pode ter mais de um pagamento (grãos diferentes) e review é por pedido, não
  por item — misturar tudo em `fct_order_items` duplicaria/deturparia as métricas de
  receita.
- **Sem nova camada `staging/`**: a camada `silver` já cumpre esse papel (limpeza +
  expectations via Lakeflow Declarative Pipelines). Modelos gold seguem o padrão já usado
  em `dim_customer.sql`, lendo direto de `{{ source('silver', ...) }}`.

## Estrutura de arquivos alvo

```
models/gold/
├── source.yml                        (já existe, sem mudanças)
├── int_geolocation/
│   └── int_geolocation.sql           (zip_code_prefix -> avg lat/lng, city/state)
├── dim_date/
│   ├── dim_date.sql
│   └── _dim_date.yml
├── dim_customer/
│   ├── dim_customer.sql              (editar: join com int_geolocation)
│   └── _dim_customer.yml             (novo: tests/docs)
├── dim_product/
│   ├── dim_product.sql
│   └── _dim_product.yml
├── dim_seller/
│   ├── dim_seller.sql                (join com int_geolocation)
│   └── _dim_seller.yml
├── fct_order_items/
│   ├── fct_order_items.sql
│   └── _fct_order_items.yml
├── fct_order_payments/
│   ├── fct_order_payments.sql
│   └── _fct_order_payments.yml
└── fct_order_reviews/
    ├── fct_order_reviews.sql
    └── _fct_order_reviews.yml
```

Cada `_<model>.yml` segue `.claude/skills/dbt-dimensional-modeling/assets/schema_template.yml`:
`unique`+`not_null` na surrogate key, `relationships` nas FKs, `not_null`/`accepted_values`
onde fizer sentido, descrições em toda coluna não óbvia.

## Checklist de fases

- [x] **Fase 0 — organização**
  Remover `models/example/` (leftover do template `default-python`, não referenciado por
  nada — mesmo espírito da observação já no CLAUDE.md sobre `main.py`/`taxis`).
  ✅ feito — pasta removida.

- [x] **Fase 1 — `dim_date`**
  Gerar com `dbt_utils.date_spine`, cobrindo o intervalo de datas do dataset Olist
  (2016-09-01 a 2018-12-31, com folga). Colunas: `date_day` (PK/surrogate), `year`,
  `month`, `month_name`, `day_of_week`, `is_weekend`, etc. Sem dependências — pode ser
  testado isoladamente primeiro.
  ✅ feito — range usado: 2016-01-01 a 2019-12-31.

- [x] **Fase 2 — `int_geolocation`**
  `select zip_code_prefix, avg(lat) as lat, avg(lng) as lng, mode(city) as city, mode(state) as state from {{ source('silver','geolocation') }} group by 1`
  (usar `first()`/`mode()` conforme suporte do Databricks SQL para city/state).
  ✅ feito.

- [x] **Fase 3 — `dim_product`**
  `silver.products` + left join `silver.product_category_name_translation` para trazer
  `product_category_name_english`. Surrogate key via
  `dbt_utils.generate_surrogate_key(['product_id'])`. Incluir dimensões físicas (peso,
  dimensões) como atributos descritivos.
  ✅ feito.

- [x] **Fase 4 — `dim_seller`**
  `silver.sellers` + left join `int_geolocation` em `seller_zip_code_prefix`. Mesma
  lógica de surrogate key.
  ✅ feito. Pendência de polimento: colunas ainda com prefixo `seller_`
  (`seller_zip_code_prefix`/`seller_city`/`seller_state`) em vez de renomear pra
  `zip_code_prefix`/`city`/`state` como em `dim_customer` — deixado para depois.

- [x] **Fase 5 — editar `dim_customer`**
  Adicionar left join com `int_geolocation` em `customer_zip_code_prefix` para trazer
  lat/lng. Manter o resto do modelo (dedup SCD1) como está.
  ✅ feito. Surrogate key ficou padronizada como `sk_customer` (usada em todas as facts).

- [x] **Fase 6 — `fct_order_items`** (fact principal)
  De `silver.order_items`, join `silver.orders` (para `customer_id`, `order_status`,
  `order_purchase_timestamp`), join `silver.customers` (para resolver
  `customer_unique_id` a partir do `customer_id` do pedido — **armadilha clássica do
  Olist**: `orders.customer_id` ≠ `dim_customer` natural key), depois resolve as
  surrogate keys de `dim_customer`, `dim_product`, `dim_seller`, `dim_date`.
  Medidas: `price`, `freight_value`. Degeneradas: `order_id`, `order_item_id`,
  `order_status`.
  ✅ feito.

- [x] **Fase 7 — `fct_order_payments`**
  De `silver.order_payments` + join `silver.orders` para resolver `sk_customer` e
  `sk_date` (data da compra). Medidas: `payment_value`, `payment_installments`.
  Degenerada: `payment_type`, `order_id`.
  ✅ feito.

- [x] **Fase 8 — `fct_order_reviews`**
  De `silver.order_reviews` + join `silver.orders` para `sk_date` (via
  `review_creation_date`) e `sk_customer`. Medida: `review_score`. Degeneradas:
  `review_id`, `order_id`, texto do comentário (não há dimensão natural para isso).
  ✅ feito. Pendência de polimento: a pasta do modelo se chama `fct_order_review`
  (singular) enquanto o arquivo/modelo é `fct_order_reviews.sql` (plural) — funciona
  normalmente no dbt (o nome do modelo vem do arquivo, não da pasta), só ficou
  inconsistente com o padrão pasta=nome-do-modelo das outras — deixado para depois.

> **Modelagem dimensional (grão, dimensões, facts, joins, surrogate keys) está
> funcionalmente pronta e revisada** neste ponto. As duas fases abaixo foram
> **conscientemente adiadas** — retomar quando fizer sentido, sem pressa.

- [ ] **Fase 9 — testes e documentação** (adiada)
  Escrever os `_<model>.yml` de cada modelo (surrogate keys únicas/not null,
  `relationships` de cada FK apontando pra dimensão certa, `accepted_values` em
  `order_status`/`payment_type`).
  Checagem de grão:
  `select order_id, order_item_id, count(*) from fct_order_items group by 1,2 having count(*) > 1`
  deve retornar zero linhas (repetir o padrão para as outras facts) — ainda não rodada
  em nenhuma fact.

- [ ] **Fase 10 — orquestração** (adiada)
  `resources/jobs/e_commerce_gold_dbt_job.job.yml` ainda só roda
  `dbt run --select dim_customer` em uma única task — os outros 6 modelos novos não
  estão sendo deployados pelo bundle, e `dbt snapshot` (histórico SCD2 do customer)
  continua nunca rodando. Trocar por uma task que builda a camada gold inteira:
  `dbt snapshot` seguido de `dbt run --select gold.*` (ou por tag, adicionando
  `+materialized: table` e uma tag `gold` em `models: data_warehouse: gold:` no
  `dbt_project.yml`), preservando a ordem de dependência via DAG do próprio dbt (não
  precisa de tasks separadas por modelo).

## Verificação

- Depois de cada fase: `cd e_commerce_lakehouse/dbt/data_warehouse && dbt run --select <model>` e inspecionar o resultado (`dbt show --select <model> --limit 10` ou consulta direta no warehouse).
- `dbt test --select <model>` para validar as expectations de cada fase antes de avançar.
- Ao final: `databricks bundle validate --target dev` e `databricks bundle run e_commerce_gold_dbt_job --target dev` (ou o orchestrator completo) para confirmar que o job builda tudo na ordem certa.
- Checagens de grão (Fase 9) em cada fact table.
