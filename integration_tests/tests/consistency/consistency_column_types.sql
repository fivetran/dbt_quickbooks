{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- BigQuery only: uses INFORMATION_SCHEMA.COLUMNS which is dataset-scoped in BQ

{% set end_models = [
    'quickbooks__ap_ar_enhanced',
    'quickbooks__balance_sheet',
    'quickbooks__cash_flow_statement',
    'quickbooks__expenses_sales_enhanced',
    'quickbooks__general_ledger',
    'quickbooks__general_ledger_by_period',
    'quickbooks__profit_and_loss'
] %}

with prod_columns as (
    {% for model in end_models %}
    select '{{ model }}' as model_name, column_name, data_type
    from `{{ target.schema }}_quickbooks_prod.INFORMATION_SCHEMA.COLUMNS`
    where table_name = '{{ model }}'
    {{ 'union all' if not loop.last }}
    {% endfor %}
),

dev_columns as (
    {% for model in end_models %}
    select '{{ model }}' as model_name, column_name, data_type
    from `{{ target.schema }}_quickbooks_dev.INFORMATION_SCHEMA.COLUMNS`
    where table_name = '{{ model }}'
    {{ 'union all' if not loop.last }}
    {% endfor %}
),

final as (
    select
        coalesce(prod.model_name, dev.model_name) as model_name,
        coalesce(prod.column_name, dev.column_name) as column_name,
        prod.data_type as prod_type,
        dev.data_type as dev_type,
        case
            when prod.column_name is null then 'column added in dev'
            when dev.column_name is null then 'column removed in dev'
            else 'type mismatch'
        end as issue
    from prod_columns prod
    full outer join dev_columns dev
        on prod.model_name = dev.model_name
        and prod.column_name = dev.column_name
    where prod.data_type != dev.data_type
        or prod.column_name is null
        or dev.column_name is null
)

select *
from final
