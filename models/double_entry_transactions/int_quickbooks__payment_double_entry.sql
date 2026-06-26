/*
Table that creates a debit record to either undeposited funds or a specified cash account and a credit record to accounts receivable.
*/

--To disable this model, set the using_payment variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_payment', True)) }}

with payments as (

    select *
    from {{ ref('stg_quickbooks__payment') }}
),

payment_lines as (

    select *
    from {{ ref('stg_quickbooks__payment_line') }}
),

accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

ar_accounts as (

    select
        account_id,
        currency_id,
        source_relation
    from accounts

    where account_type = '{{ var('quickbooks__accounts_receivable_reference', 'Accounts Receivable') }}'
        and is_active
        and not is_sub_account
),

{% if var('quickbooks__generate_exchange_gain_loss', True) %}
exchange_gain_loss_accounts as (

    select
        account_id,
        source_relation
    from accounts

    where account_sub_type = 'ExchangeGainOrLoss'
),
{% endif %}

payment_join as (

    select
        payments.payment_id as transaction_id,
        payments.source_relation,
        row_number() over (partition by payments.payment_id {{ fivetran_utils.partition_by_source_relation(package_name='quickbooks', alias='payments') }}  
            order by payments.transaction_date) - 1 as index,
        payments.transaction_date,
        payments.total_amount as amount,
        case
            when payments.currency_id = '{{ var('quickbooks__home_currency', '') }}'
                then payments.total_amount
            else payments.total_amount * coalesce(payments.exchange_rate, 1)
        end as converted_amount,
        payments.deposit_to_account_id,
        payments.receivable_account_id,
        payments.customer_id,
        payments.currency_id,
        payments.created_at,
        payments.updated_at
    from payments
),

{% if var('quickbooks__generate_exchange_gain_loss', True) %}
gain_loss_join as (

    select
        payments.payment_id as transaction_id,
        payments.source_relation,
        payment_lines.index,
        payments.transaction_date,
        abs((coalesce(payments.exchange_rate, 1) - coalesce(invoices.exchange_rate, 1)) * payment_lines.amount) as amount,
        abs((coalesce(payments.exchange_rate, 1) - coalesce(invoices.exchange_rate, 1)) * payment_lines.amount) as converted_amount,
        exchange_gain_loss_accounts.account_id,
        payments.customer_id,
        payments.created_at,
        payments.updated_at,
        cast(case
            when (coalesce(payments.exchange_rate, 1) - coalesce(invoices.exchange_rate, 1)) * payment_lines.amount >= 0
                then 'credit'
            else 'debit'
        end as {{ dbt.type_string() }}) as transaction_type
    from payments

    inner join payment_lines
        on payments.payment_id = payment_lines.payment_id
        and payments.source_relation = payment_lines.source_relation

    inner join invoices
        on payment_lines.invoice_id = invoices.invoice_id
        and payment_lines.source_relation = invoices.source_relation

    inner join exchange_gain_loss_accounts
        on exchange_gain_loss_accounts.source_relation = payments.source_relation

    where payments.currency_id != '{{ var('quickbooks__home_currency', '') }}'
        and coalesce(payments.exchange_rate, 1) != coalesce(invoices.exchange_rate, 1)
),
{% endif %}

final as (

    select
        transaction_id,
        payment_join.source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        converted_amount,
        deposit_to_account_id as account_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        cast(null as {{ dbt.type_string() }}) as department_id,
        created_at,
        updated_at,
        cast('debit' as {{ dbt.type_string() }}) as transaction_type,
        cast('payment' as {{ dbt.type_string() }}) as transaction_source
    from payment_join

    union all

    select
        transaction_id,
        payment_join.source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        converted_amount,
        coalesce(receivable_account_id, ar_accounts.account_id) as account_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        cast(null as {{ dbt.type_string() }}) as department_id,
        created_at,
        updated_at,
        cast('credit' as {{ dbt.type_string() }}) as transaction_type,
        cast('payment' as {{ dbt.type_string() }}) as transaction_source
    from payment_join

    left join ar_accounts
        on ar_accounts.currency_id = payment_join.currency_id
        and ar_accounts.source_relation = payment_join.source_relation

{% if var('quickbooks__generate_exchange_gain_loss', True) %}

    union all

    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        converted_amount,
        account_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        cast(null as {{ dbt.type_string() }}) as department_id,
        created_at,
        updated_at,
        transaction_type,
        cast('payment' as {{ dbt.type_string() }}) as transaction_source
    from gain_loss_join

{% endif %}
)

select *
from final