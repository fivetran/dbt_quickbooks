{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (
    select
        account_id,
        count(*) as row_count,
        sum(cast(period_net_change as {{ dbt.type_numeric() }})) as period_net_change
    from {{ target.schema }}_quickbooks.quickbooks__general_ledger_by_period
    group by 1
),

dev as (
    select
        account_id,
        count(*) as row_count,
        sum(cast(period_net_change as {{ dbt.type_numeric() }})) as period_net_change
    from {{ target.schema }}_quickbooks.quickbooks__general_ledger_by_period
    group by 1
),

final as (
    select 
        prod.account_id,
        prod.row_count as prod_row_count,
        dev.row_count as dev_row_count,
        round(prod.period_net_change, 2) as prod_period_net_change,
        round(dev.period_net_change, 2) as dev_period_net_change
    from prod
    full outer join dev 
        on dev.account_id = prod.account_id
)

select *
from final
where (prod_row_count != dev_row_count 
        or prod_period_net_change != dev_period_net_change
    )
    {{ "and transaction_id not in " ~ var('fivetran_consistency_general_ledger_by_period_exclusion_documents',[]) ~ "" if var('fivetran_consistency_general_ledger_by_period_exclusion_documents',[]) }}