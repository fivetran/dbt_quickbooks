--To disable this model, set the using_deposit variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_deposit', True)) }}

with deposits as (
    select *
    from {{ref('stg_quickbooks__deposit')}}
),

deposit_lines as (
    select *
    from {{ref('stg_quickbooks__deposit_line')}}
),

final as (
    select
        deposits.deposit_id as transaction_id,
        deposit_lines.index as transaction_line_id,
        cast(null as {{ dbt_utils.type_string() }}) as doc_number,
        'deposit' as transaction_type,
        deposits.transaction_date,
        deposit_lines.deposit_account_id as account_id,
        deposit_lines.deposit_class_id as class_id,
        deposits.department_id,
        deposit_lines.deposit_customer_id as customer_id,
        cast(null as {{ dbt_utils.type_string() }}) as vendor_id,
        cast(null as {{ dbt_utils.type_string() }}) as billable_status,
        deposit_lines.description,
        deposit_lines.amount,
        deposits.total_amount
    from deposits

    inner join deposit_lines
        on deposits.deposit_id = deposit_lines.deposit_id
)

select *
from final
