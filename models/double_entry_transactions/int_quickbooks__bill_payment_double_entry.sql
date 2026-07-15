/*
Table that creates a debit record to accounts payable and a credit record to the specified cash account.
*/

--To disable this model, set the using_bill_payment variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_bill', True)) }}

{%- set using_exchange_gain_loss = var('quickbooks__exchange_gain_loss_enabled', False) %}

with bill_payments as (

    select *
    from {{ ref('stg_quickbooks__bill_payment') }}
),

bill_payment_lines as (

    select *
    from {{ ref('stg_quickbooks__bill_payment_line') }}
),

accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

ap_accounts as (

    select
        account_id,
        currency_id,
        source_relation
    from accounts

    where account_type = '{{ var('quickbooks__accounts_payable_reference', 'Accounts Payable') }}'
        and is_active
        and not is_sub_account
),

{% if using_exchange_gain_loss %}
exchange_gain_loss_accounts as (

    select
        account_id,
        source_relation
    from accounts

    where account_sub_type = 'ExchangeGainOrLoss'
        and is_active
        and not is_sub_account
),
{% endif %}

bill_payment_join as (

    select
        bill_payments.bill_payment_id as transaction_id,
        bill_payments.source_relation,
        row_number() over(partition by bill_payments.bill_payment_id {{ fivetran_utils.partition_by_source_relation(package_name='quickbooks', alias='bill_payments') }}
            order by bill_payments.transaction_date) - 1 as index,
        bill_payments.transaction_date,
        bill_payments.total_amount as amount,
        case
            when bill_payments.currency_id = '{{ var('quickbooks__home_currency', '') }}'
                then bill_payments.total_amount
            else bill_payments.total_amount * coalesce(bill_payments.exchange_rate, 1)
        end as converted_amount,
        coalesce(bill_payments.credit_card_account_id, bill_payments.check_bank_account_id) as payment_account_id,
        ap_accounts.account_id,
        bill_payments.vendor_id,
        bill_payments.department_id,
        bill_payments.created_at,
        bill_payments.updated_at
    from bill_payments

    left join ap_accounts
         on ap_accounts.account_id = bill_payments.payable_account_id
         and ap_accounts.source_relation = bill_payments.source_relation
),

{% if using_exchange_gain_loss %}
bills as (

    select *
    from {{ ref('stg_quickbooks__bill') }}
),

bill_original_amounts as (

    -- computes the AP amount to clear using each bill's original exchange rate
    select
        bill_payments.bill_payment_id,
        bill_payments.source_relation,
        sum(bill_payment_lines.amount * coalesce(bills.exchange_rate, 1)) as ap_converted_amount
    from bill_payments

    inner join bill_payment_lines
        on bill_payments.bill_payment_id = bill_payment_lines.bill_payment_id
        and bill_payments.source_relation = bill_payment_lines.source_relation

    inner join bills
        on bill_payment_lines.bill_id = bills.bill_id
        and bill_payment_lines.source_relation = bills.source_relation

    where bill_payments.currency_id != '{{ var('quickbooks__home_currency', '') }}'

    group by 1,2
),

gain_loss_join as (

    select
        bill_payments.bill_payment_id as transaction_id,
        bill_payments.source_relation,
        bill_payment_lines.index,
        bill_payments.transaction_date,
        abs((coalesce(bill_payments.exchange_rate, 1) - coalesce(bills.exchange_rate, 1)) * bill_payment_lines.amount) as amount,
        abs((coalesce(bill_payments.exchange_rate, 1) - coalesce(bills.exchange_rate, 1)) * bill_payment_lines.amount) as converted_amount,
        exchange_gain_loss_accounts.account_id,
        bill_payments.vendor_id,
        bill_payments.department_id,
        bill_payments.created_at,
        bill_payments.updated_at,
        cast(case
            when (coalesce(bill_payments.exchange_rate, 1) - coalesce(bills.exchange_rate, 1)) * bill_payment_lines.amount >= 0
                then 'debit'
            else 'credit'
        end as {{ dbt.type_string() }}) as transaction_type
    from bill_payments

    inner join bill_payment_lines
        on bill_payments.bill_payment_id = bill_payment_lines.bill_payment_id
        and bill_payments.source_relation = bill_payment_lines.source_relation

    inner join bills
        on bill_payment_lines.bill_id = bills.bill_id
        and bill_payment_lines.source_relation = bills.source_relation

    inner join exchange_gain_loss_accounts
        on exchange_gain_loss_accounts.source_relation = bill_payments.source_relation

    where bill_payments.currency_id != '{{ var('quickbooks__home_currency', '') }}'
        and coalesce(bill_payments.exchange_rate, 1) != coalesce(bills.exchange_rate, 1)
),
{% endif %}

final as (

    -- credit to cash/bank account
    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        cast(null as {{ dbt.type_string() }}) as customer_id,
        vendor_id,
        amount,
        converted_amount,
        payment_account_id as account_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        department_id,
        created_at,
        updated_at,
        cast('credit' as {{ dbt.type_string() }}) as transaction_type,
        cast('bill payment' as {{ dbt.type_string() }}) as transaction_source
    from bill_payment_join

    union all

    -- debit to accounts payable at the original bill exchange rate
    select
        bill_payment_join.transaction_id,
        bill_payment_join.source_relation,
        bill_payment_join.index,
        bill_payment_join.transaction_date,
        cast(null as {{ dbt.type_string() }}) as customer_id,
        bill_payment_join.vendor_id,
        bill_payment_join.amount,
        {% if using_exchange_gain_loss %}
        coalesce(bill_original_amounts.ap_converted_amount, bill_payment_join.converted_amount) as converted_amount,
        {% else %}
        bill_payment_join.converted_amount,
        {% endif %}
        bill_payment_join.account_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        bill_payment_join.department_id,
        bill_payment_join.created_at,
        bill_payment_join.updated_at,
        cast('debit' as {{ dbt.type_string() }}) as transaction_type,
        cast('bill payment' as {{ dbt.type_string() }}) as transaction_source
    from bill_payment_join

{% if using_exchange_gain_loss %}
    left join bill_original_amounts
        on bill_original_amounts.bill_payment_id = bill_payment_join.transaction_id
        and bill_original_amounts.source_relation = bill_payment_join.source_relation

    union all

    -- debit/credit to exchange gain or loss account for foreign currency rate difference
    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        cast(null as {{ dbt.type_string() }}) as customer_id,
        vendor_id,
        amount,
        converted_amount,
        account_id,
        cast(null as {{ dbt.type_string() }}) as class_id,
        department_id,
        created_at,
        updated_at,
        transaction_type,
        cast('bill payment' as {{ dbt.type_string() }}) as transaction_source
    from gain_loss_join

{% endif %}
)

select *
from final
