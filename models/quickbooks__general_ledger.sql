with gl_union as (
    select
        transaction_id,
        transaction_date,
        amount,
        account_id,
        transaction_type,
        transaction_source
    from {{ref('int_quickbooks__purchase_double_entry')}}

    union all

    select *
    from {{ref('int_quickbooks__sales_receipt_double_entry')}}

    {% if var('using_bill', True) %}
    union all

    select *
    from {{ref('int_quickbooks__bill_payment_double_entry')}}

    union all

    select *
    from {{ref('int_quickbooks__bill_double_entry')}}
    {% endif %}

    {% if var('using_credit_memo', True) %}
    union all

    select *
    from {{ref('int_quickbooks__credit_memo_double_entry')}}
    {% endif %}

    {% if var('using_deposit', True) %}
    union all

    select *
    from {{ref('int_quickbooks__deposit_double_entry')}}
    {% endif %}

    {% if var('using_invoice', True) %}
    union all

    select *
    from {{ref('int_quickbooks__invoice_double_entry')}}
    {% endif %}

    {% if var('using_transfer', True) %}
    union all

    select *
    from {{ref('int_quickbooks__transfer_double_entry')}}
    {% endif %}

    {% if var('using_journal_entry', True) %}
    union all

    select *
    from {{ref('int_quickbooks__journal_entry_double_entry')}}
    {% endif %}

    {% if var('using_payment', True) %}
    union all

    select *
    from {{ref('int_quickbooks__payment_double_entry')}}
    {% endif %}

    {% if var('using_refund_receipt', True) %}
    union all

    select *
    from {{ref('int_quickbooks__refund_receipt_double_entry')}}
    {% endif %}

    {% if var('using_vendor_credit', True) %}
    union all

    select *
    from {{ref('int_quickbooks__vendor_credit_double_entry')}}
    {% endif %}
),

accounts as (
    select *
    from {{ref('int_quickbooks__account_classifications')}}
),


adjusted_gl as (
    select
        gl_union.transaction_id,
        row_number() over(partition by gl_union.transaction_id order by gl_union.transaction_date) as transaction_index,
        gl_union.transaction_date,
        cast(gl_union.amount as decimal) as amount,
        gl_union.account_id,
        accounts.name as account_name,
        accounts.account_type,
        accounts.account_sub_type,
        accounts.financial_statement_helper,
        accounts.balance as account_current_balance,
        accounts.classification as account_class, 
        gl_union.transaction_type,
        gl_union.transaction_source,
        accounts.transaction_type as account_transaction_type,
        case when accounts.transaction_type = gl_union.transaction_type
            then cast(gl_union.amount as decimal)
            else cast(gl_union.amount as decimal) * -1
                end as adjusted_amount
    from gl_union

    left join accounts
        on gl_union.account_id = accounts.account_id
),

final as (
    select
        *,
        round(cast(sum(adjusted_amount) over (partition by account_id order by transaction_date, account_id rows unbounded preceding) as decimal),2) as running_balance
    from adjusted_gl
)

select *
from final