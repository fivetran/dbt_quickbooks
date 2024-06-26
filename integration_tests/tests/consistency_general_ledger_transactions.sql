{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with prod as (
    select
        1 as join_key,
        count(*) as total_transactions
    from {{ target.schema }}_quickbooks_prod.quickbooks__general_ledger
    group by 1
),

dev as (

    select         
        1 as join_key,
        count(*) as total_transactions
    from {{ target.schema }}_quickbooks_dev.quickbooks__general_ledger
    group by 1
),

final as (

    select 
        prod.join_key,
        prod.total_transactions as prod_total_transactions,
        dev.total_transactions as dev_total_transactions
    from prod
    full outer join dev 
        on dev.join_key = prod.join_key
)

select *
from final
where prod_total_transactions != dev_total_transactions