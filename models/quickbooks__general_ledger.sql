with gl_union as (
    select
        transaction_id,
        transaction_date,
        customer_id,
        vendor_id,
        amount,
        account_id,
        transaction_type,
        transaction_source,
        source_relation
    from {{ref('int_quickbooks__purchase_double_entry')}}

    {% if var('using_sales_receipt', True) %}
    union all

    select *
    from {{ref('int_quickbooks__sales_receipt_double_entry')}}
    {% endif %}

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
        gl_union.customer_id,
        gl_union.vendor_id,
        gl_union.amount,
        gl_union.account_id,
        accounts.account_number,
        accounts.name as account_name,
        accounts.is_sub_account,
        accounts.parent_account_number,
        accounts.parent_account_name,
        accounts.account_type,
        accounts.account_sub_type,
        accounts.financial_statement_helper,
        accounts.balance as account_current_balance,
        accounts.classification as account_class,
        gl_union.transaction_type,
        gl_union.transaction_source,
        accounts.transaction_type as account_transaction_type,
        case when accounts.transaction_type = gl_union.transaction_type
            then gl_union.amount
            else gl_union.amount * -1
                end as adjusted_amount,
        gl_union.source_relation
    from gl_union

    left join accounts
        on (gl_union.account_id = accounts.account_id
        and gl_union.source_relation = accounts.source_relation)
),

final as (
    select
        *,
        sum(adjusted_amount) over (partition by source_relation, account_id order by transaction_date, source_relation, account_id rows unbounded preceding) as running_balance
    from adjusted_gl
)

select *
from final
