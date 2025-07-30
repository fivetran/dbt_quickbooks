/*
Table that creates a debit record to the specified asset account and a credit record the specified cash account.
*/

--To disable this model, set the using_refund_receipt variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_refund_receipt', True)) }}

with refund_receipts as (

    select *
    from {{ ref('stg_quickbooks__refund_receipt') }}
),

refund_receipt_lines as (

    select *
    from {{ ref('stg_quickbooks__refund_receipt_line') }}
),

accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

{% if var('using_refund_receipt_tax_line', False) %}

refund_receipt_tax_lines as (

    select refund_receipt_id,
        source_relation,
        index + 10000 as index,
        tax_rate_id,
        amount,
        tax_percent
    from {{ ref('stg_quickbooks__refund_receipt_tax_line') }}
),
{% endif %}

{% if var('using_tax_agency', False) %}
tax_agencies as (

    select *
    from {{ ref('stg_quickbooks__tax_agency') }}
),
{% endif %}

{% if var('using_tax_rate', False) %}
tax_rates as (

    select *
    from {{ ref('stg_quickbooks__tax_rate') }}
),
{% endif %}

items as (

    select
        item.*,
        parent.income_account_id as parent_income_account_id
    from {{ ref('stg_quickbooks__item') }} item

    left join {{ ref('stg_quickbooks__item') }} parent
        on item.parent_item_id = parent.item_id
        and item.source_relation = parent.source_relation
),


liability_accounts as (

    select
        account_id,
        name,
        source_relation
    from accounts
    where classification = 'Liability' 
        and is_active
),

sales_tax_account as (

    select
        account_id,
        source_relation
    from accounts
    where name = '{{ var('quickbooks__sales_tax_account_reference', 'Sales Tax Payable') }}'
        and is_active
),

global_tax_account as (

    select
        account_id,
        source_relation
    from accounts
    where name = '{{ var('quickbooks__global_tax_account_reference', 'Global Tax Payable') }}'
        and is_active 
),


tax_account_join as (

    {% if var('using_tax_agency', False) %}
    select 
        tax_agencies.tax_agency_id,
        tax_agencies.display_name,
        coalesce(liability_accounts.account_id, sales_tax_account.account_id, global_tax_account.account_id) as account_id,
        coalesce(liability_accounts.source_relation, sales_tax_account.source_relation, global_tax_account.source_relation) as source_relation

    from tax_agencies
    
    left join liability_accounts
        on {{ dbt.concat([
            "tax_agencies.display_name", 
            "' Payable'"]) }} = liability_accounts.name
        and tax_agencies.source_relation = liability_accounts.source_relation
    left join sales_tax_account
        on tax_agencies.source_relation = sales_tax_account.source_relation

    left join global_tax_account
        on tax_agencies.source_relation = global_tax_account.source_relation

    {% else %}
    -- Fallback mapping for when tax_agency is disabled
    select
        coalesce(sales_tax_account.account_id, global_tax_account.account_id) as account_id,
        coalesce(sales_tax_account.source_relation, global_tax_account.source_relation) as source_relation
    from sales_tax_account
    full outer join global_tax_account
        on sales_tax_account.source_relation = global_tax_account.source_relation

    {% endif %}
), 

refund_receipt_join as (

    select
        refund_receipts.refund_id as transaction_id,
        refund_receipts.source_relation,
        refund_receipt_lines.index,
        refund_receipts.transaction_date,
        refund_receipt_lines.amount,
        (refund_receipt_lines.amount * coalesce(refund_receipts.exchange_rate, 1)) as converted_amount,
        refund_receipts.deposit_to_account_id as credit_to_account_id,
        coalesce(refund_receipt_lines.discount_account_id, refund_receipt_lines.sales_item_account_id, items.parent_income_account_id, items.income_account_id) as debit_account_id,
        refund_receipts.customer_id,
        coalesce(refund_receipt_lines.sales_item_class_id, refund_receipt_lines.discount_class_id, refund_receipts.class_id) as class_id,
        refund_receipts.department_id,
        refund_receipts.created_at,
        refund_receipts.updated_at
    from refund_receipts

    inner join refund_receipt_lines
        on refund_receipts.refund_id = refund_receipt_lines.refund_id
        and refund_receipts.source_relation = refund_receipt_lines.source_relation

    left join items
        on refund_receipt_lines.sales_item_item_id = items.item_id
        and refund_receipt_lines.source_relation = items.source_relation

    where coalesce(refund_receipt_lines.discount_account_id, refund_receipt_lines.sales_item_account_id, refund_receipt_lines.sales_item_item_id) is not null

    {% if var('using_refund_receipt_tax_line', False) %}
    union all

    select
        refund_receipt_tax_lines.refund_receipt_id as transaction_id,
        refund_receipt_tax_lines.source_relation,
        refund_receipt_tax_lines.index,
        refund_receipts.transaction_date,
        refund_receipt_tax_lines.amount,
        refund_receipt_tax_lines.amount * coalesce(refund_receipts.exchange_rate, 1) as converted_amount,
        refund_receipts.deposit_to_account_id as credit_to_account_id,
        tax_account_join.account_id as debit_account_id,
        refund_receipts.customer_id,
        cast(null as {{ dbt.type_string() }}) as class_id,        
        refund_receipts.department_id,
        refund_receipts.created_at,
        refund_receipts.updated_at
    from refund_receipt_tax_lines
    inner join refund_receipts 
        on refund_receipt_tax_lines.refund_receipt_id = refund_receipts.refund_id
        and refund_receipt_tax_lines.source_relation = refund_receipts.source_relation
    
    {% if var('using_tax_rate', False) %}
    left join tax_rates
        on refund_receipt_tax_lines.tax_rate_id = tax_rates.tax_rate_id
        and refund_receipt_tax_lines.source_relation = tax_rates.source_relation
    {% endif %}

    left join tax_account_join
        {% if var('using_tax_rate', False) %}
        on tax_rates.tax_agency_id = tax_account_join.tax_agency_id
        and tax_rates.source_relation = tax_account_join.source_relation
        {% else %}
        on refund_receipt_tax_lines.source_relation = tax_account_join.source_relation
        {% endif %}
    {% endif %}
),

final as (

    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        cast(null as {{ dbt.type_string() }}) as vendor_id,
        amount,
        converted_amount,
        credit_to_account_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        'credit' as transaction_type,
        'refund_receipt' as transaction_source
    from refund_receipt_join

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
        debit_account_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        'debit' as transaction_type,
        'refund_receipt' as transaction_source
    from refund_receipt_join
)

select *
from final
