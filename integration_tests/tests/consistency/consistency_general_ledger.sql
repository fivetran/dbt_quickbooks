{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (
    select
        transaction_id,
        count(*) as row_count,
        sum(cast(amount as {{ dbt.type_numeric() }})) as initial_amount,
        sum(cast(adjusted_amount as {{ dbt.type_numeric() }})) as total_adjusted_amount
    from {{ target.schema }}_quickbooks.quickbooks__general_ledger
    group by 1
),

dev as (
    select
        transaction_id,
        count(*) as row_count,
        sum(cast(amount as {{ dbt.type_numeric() }})) as initial_amount,
        sum(cast(adjusted_amount as {{ dbt.type_numeric() }})) as total_adjusted_amount
    from {{ target.schema }}_quickbooks.quickbooks__general_ledger
    group by 1
),

final as (
    select 
        prod.transaction_id,
        prod.row_count as prod_row_count,
        dev.row_count as dev_row_count,
        round(prod.initial_amount, 2) as prod_initial_amount,
        round(dev.initial_amount, 2) as dev_initial_amount,
        round(prod.total_adjusted_amount, 2) as prod_total_adjusted_amount,
        round(dev.total_adjusted_amount, 2) as dev_total_adjusted_amount
    from prod
    full outer join dev 
        on dev.transaction_id = prod.transaction_id
)

select *
from final
where (prod_row_count != dev_row_count 
        or prod_initial_amount != dev_initial_amount 
        or prod_total_adjusted_amount != dev_total_adjusted_amount
    )
    {{ "and transaction_id not in " ~ var('fivetran_consistency_general_ledger_exclusion_documents',[]) ~ "" if var('fivetran_consistency_general_ledger_exclusion_documents',[]) }}