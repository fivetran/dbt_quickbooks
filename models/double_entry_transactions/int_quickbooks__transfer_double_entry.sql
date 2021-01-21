--To disable this model, set the using_transfer variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_transfer', True)) }}

with transfers as (
    select *
    from {{ref('stg_quickbooks__transfer')}}
),

transfer_body as (
    select
        transfer_id as transaction_id,
        transaction_date,
        amount,
        from_account_id as credit_to_account_id,
        to_account_id as debit_to_account_id
    from transfers
),

final as (
    select 
        transaction_id,
        transaction_date,
        amount,
        credit_to_account_id as account_id,
        'credit' as transaction_type,
        'transfer' as transaction_source
    from transfer_body

    union all

    select 
        transaction_id,
        transaction_date,
        amount,
        debit_to_account_id as account_id,
        'debit' as transaction_type,
        'transfer' as transaction_source
    from transfer_body
)

select *
from final