
{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (
    select
        account_id,
        calendar_date,
        amount
    from {{ target.schema }}_quickbooks.quickbooks__balance_sheet
),

dev as (
    select
        account_id,
        calendar_date,
        amount
    from {{ target.schema }}_quickbooks.quickbooks__balance_sheet
),

final as (
    select 
        prod.account_id,
        prod.calendar_date,
        round(prod.amount, 2) as prod_amount,
        round(dev.amount, 2) as dev_amount
    from prod
    full outer join dev 
        on dev.account_id = prod.account_id
        and dev.calendar_date = prod.calendar_date
)

select *
from final
where (prod_amount != dev_amount)
    {{ "and transaction_id not in " ~ var('fivetran_consistency_balance_sheet_exclusion_documents',[]) ~ "" if var('fivetran_consistency_balance_sheet_exclusion_documents',[]) }}