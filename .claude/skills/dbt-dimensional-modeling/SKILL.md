---
name: dbt-dimensional-modeling
description: Guides data engineering work in dbt that involves designing or building a dimensional model (star schema) — identifying grain, dimensions and facts, structuring the staging/intermediate/marts layers, naming conventions, surrogate keys, SCD Type 2 dimensions via snapshots, fact table types (transaction, periodic snapshot, accumulating snapshot), and testing. Use this skill whenever the user mentions dbt models, data marts, star schema, fact/dimension tables, Kimball, data warehouse modeling, or asks to model a business process for analytics — even if they don't say "dimensional modeling" explicitly. Also use when reviewing or refactoring existing dbt projects for warehouse modeling best practices.
---

# dbt Dimensional Modeling (Kimball)

A skill for designing and implementing dimensional models (star schemas) inside a dbt project, following Kimball methodology adapted to dbt's layered architecture.

## Core process — always start here

Before writing any SQL, work through these four Kimball questions with the user. Don't skip to code — a fact table built on the wrong grain has to be rebuilt.

1. **Business process** — what real-world process are we modeling? (orders placed, shipments, support tickets, page views...)
2. **Grain** — what does exactly one row in the fact table represent? Be explicit: "one row per order line item," not "one row per order." This is the single most important decision — get it in writing before modeling.
3. **Dimensions** — what descriptive context does the business want to slice/filter by? (customer, product, date, store, channel...)
4. **Facts** — what numeric measurements exist at that grain? (quantity, unit_price, discount_amount...) If a measurement doesn't exist at the declared grain, it belongs in a different fact table.

If the user hasn't answered these yet, ask before building. If they've given you source tables and a business question, infer draft answers and confirm before proceeding.

## dbt layer architecture

```
models/
├── staging/
│   └── <source>/
│       ├── _<source>__sources.yml
│       ├── stg_<source>__<entity>.sql
│       └── _stg_<source>__models.yml
├── intermediate/
│   └── int_<entity>__<verb>.sql
└── marts/
    └── <domain>/
        ├── dim_<entity>.sql
        ├── fct_<entity>.sql
        └── _<domain>__models.yml
```

- **staging**: one model per source table. 1:1 with source, light cleaning only (renaming, type casting, basic reshaping). No joins across sources. Materialize as `view`.
- **intermediate**: reusable building blocks — joins, unions, aggregations that feed more than one mart, or that make a mart model too complex to read otherwise. Materialize as `view` or `ephemeral`. Skip this layer if a mart is simple enough to build directly from staging.
- **marts**: the star schema itself — `dim_` and `fct_` models, organized by business domain (e.g. `marts/finance/`, `marts/marketing/`). This is what BI tools query. Materialize dimensions as `table`, facts as `table` or `incremental` depending on volume.

Full naming conventions and materialization guidance: see `references/naming-conventions.md`.

## Building dimensions

- One row per natural key (per surrogate key, if SCD2 — see below).
- Generate the surrogate key with `dbt_utils.generate_surrogate_key(['natural_key_col', ...])` — never a hand-rolled hash or a plain sequence, so keys stay stable across warehouses and full-refreshes.
- Include a `_loaded_at` / `dbt_updated_at` audit column.
- Denormalize freely — a dimension can and should pull in flat, human-readable attributes from other reference tables. Analysts should almost never need to join two dimensions together.
- Always add a "Unknown" / -1 row for handling orphaned foreign keys in facts (via a `union all` with a hardcoded literal row, or `dbt_utils.get_column_values` + seed).

### Slowly Changing Dimensions (SCD Type 2)

Use dbt **snapshots** — do not hand-roll SCD2 logic in a model. See `references/scd-type-2.md` for the full snapshot config, the `dbt_valid_from`/`dbt_valid_to` contract, and how to build a `dim_` model on top of a snapshot. Default to Type 2 for any dimension the business says "I need to see what it looked like at the time of the transaction" (e.g., customer tier, product price, sales rep assignment). Default to Type 1 (overwrite, no history) for everything else — don't snapshot dimensions nobody asked to track history on.

## Building facts

First classify which of the three Kimball fact table types you're building — this decides the model's incremental strategy:

| Type | Grain example | Incremental strategy |
|---|---|---|
| **Transaction fact** | one row per event (order line, click) | `insert_overwrite` or `append`, filtered on a high-watermark timestamp |
| **Periodic snapshot** | one row per entity per period (account balance at month-end) | `insert_overwrite` partitioned by the period column |
| **Accumulating snapshot** | one row per process instance, columns updated as it moves through stages (order: placed_at, shipped_at, delivered_at) | full-refresh or `merge` keyed on the natural key, since existing rows get updated in place |

- Foreign keys in the fact table must be the dimensions' **surrogate keys**, not natural keys — that's what makes SCD2 joins correct (join on the surrogate key valid at the time of the fact's timestamp, not the current one).
- Facts should be additive (safely `SUM`-able across all dimensions) wherever possible. Flag semi-additive facts (e.g. account balances — summable across everything except time) and non-additive facts (e.g. ratios) explicitly in the model's documentation.
- Never put descriptive/text attributes in a fact table — if you're tempted to add a varchar column to a fact, it belongs in a dimension instead (possibly a new junk dimension for flags/indicators).
- For incremental models, always test the incremental logic separately with `dbt run --full-refresh` vs. incremental run to confirm row counts reconcile.

## Testing and documentation

Every mart model needs a corresponding entry in a `_<domain>__models.yml`:
- `unique` + `not_null` on every primary/surrogate key
- `relationships` test on every foreign key pointing to its dimension
- `not_null` on every fact column that should never be null
- `accepted_values` on any dimension attribute with a known, finite set of values
- A `description` on the model and on every column an analyst couldn't infer from the name alone — this is what populates dbt docs

Prefer generic tests over singular test SQL files; reach for `dbt_utils` tests (`dbt_utils.expression_is_true`, `dbt_utils.unique_combination_of_columns`) before writing custom ones.

## Workflow checklist

When asked to model a new business process, work through this in order and confirm with the user at each checkpoint before moving to the next:

1. Confirm business process, grain, dimensions, facts (see Core process above)
2. Identify/inspect source tables → check if staging models already exist for them; if not, build those first
3. Sketch the dimension list and which are SCD1 vs SCD2
4. Build/update dimensions (snapshot + dim model for SCD2, direct dim model for SCD1)
5. Build the fact table at the agreed grain, joined to dimension surrogate keys
6. Add tests and documentation
7. Sanity-check row counts and grain (`select natural_key, count(*) from fct_x group by 1 having count(*) > 1` should return zero rows)

## Reference files

- `references/naming-conventions.md` — full file/model naming rules and materialization defaults per layer
- `references/scd-type-2.md` — dbt snapshot config, valid_from/valid_to contract, building a dim on top of a snapshot
- `references/fact-table-patterns.md` — detailed SQL patterns for each of the three fact table types, plus the "Unknown member" pattern for dimensions
- `assets/` — copy-paste starter templates: `stg_template.sql`, `dim_template.sql`, `dim_scd2_snapshot.sql`, `fct_transaction_template.sql`, `fct_periodic_snapshot_template.sql`, `schema_template.yml`
