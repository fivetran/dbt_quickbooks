/*
Table that creates a debit record to the specified cash account and a credit record to the specified asset account.
*/

--To disable this model, set the using_sales_receipt variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_sales_receipt', True)) }}

with sales_receipts as (

    select *
    from {{ ref('stg_quickbooks__sales_receipt') }}
),

sales_receipt_lines as (

    select *
    from {{ ref('stg_quickbooks__sales_receipt_line') }}
),

accounts as (

    select *
    from {{ ref('stg_quickbooks__account') }}
),

{% if var('using_sales_receipt_tax_line', False) %}

sales_receipt_tax_lines as (

    select sales_receipt_id,
        source_relation,
        index + 10000 as index,
        tax_rate_id,
        amount,
        tax_percent
    from {{ ref('stg_quickbooks__sales_receipt_tax_line') }}
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
    where name = '{{ var('quickbooks__sales_tax_account', 'Sales Tax Payable') }}'
        and is_active
),

global_tax_account as (

    select
        account_id,
        source_relation
    from accounts
    where name = '{{ var('quickbooks__global_tax_account', 'Sales Tax Payable') }}'
        and is_active
),

{% if var('using_tax_agency', False) %}
tax_account_join as (

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
),
{% endif %}

sales_receipt_join as (

    select
        sales_receipts.sales_receipt_id as transaction_id,
        sales_receipts.source_relation,
        sales_receipt_lines.index,
        sales_receipts.transaction_date,
        case 
            when sales_receipt_lines.discount_account_id is not null 
            then sales_receipt_lines.amount * (-1)
            else sales_receipt_lines.amount
        end as amount,
        case 
            when sales_receipt_lines.discount_account_id is not null 
            then (sales_receipt_lines.amount * coalesce(-sales_receipts.exchange_rate, -1))
            else (sales_receipt_lines.amount * coalesce(sales_receipts.exchange_rate, 1))
        end as converted_amount,
        sales_receipts.deposit_to_account_id as debit_to_account_id,
        coalesce(sales_receipt_lines.discount_account_id, sales_receipt_lines.sales_item_account_id, items.parent_income_account_id, items.income_account_id) as credit_to_account_id,
        sales_receipts.customer_id,
        coalesce(sales_receipt_lines.sales_item_class_id, sales_receipt_lines.discount_class_id, sales_receipts.class_id) as class_id,
        sales_receipts.department_id,
        sales_receipts.created_at,
        sales_receipts.updated_at
    from sales_receipts

    inner join sales_receipt_lines
        on sales_receipts.sales_receipt_id = sales_receipt_lines.sales_receipt_id
        and sales_receipts.source_relation = sales_receipt_lines.source_relation

    left join items
        on sales_receipt_lines.sales_item_item_id = items.item_id
        and sales_receipt_lines.source_relation = items.source_relation

    where coalesce(sales_receipt_lines.discount_account_id, sales_receipt_lines.sales_item_account_id, sales_receipt_lines.sales_item_item_id) is not null

    {% if var('using_sales_receipt_tax_line', False) and var('using_tax_rate', False) and var('using_tax_agency', False) %}
    union all

    select
        sales_receipt_tax_lines.sales_receipt_id as transaction_id,
        sales_receipt_tax_lines.source_relation,
        sales_receipt_tax_lines.index,
        sales_receipts.transaction_date,
        sales_receipt_tax_lines.amount,
        sales_receipt_tax_lines.amount * coalesce(sales_receipts.exchange_rate, 1) as converted_amount,
        sales_receipts.deposit_to_account_id as debit_to_account_id,
        tax_account_join.account_id as credit_to_account_id,
        sales_receipts.customer_id,
        cast(null as {{ dbt.type_string() }}) as class_id,        
        sales_receipts.department_id,
        sales_receipts.created_at,
        sales_receipts.updated_at
    from sales_receipt_tax_lines
    inner join sales_receipts 
        on sales_receipt_tax_lines.sales_receipt_id = sales_receipts.sales_receipt_id
        and sales_receipt_tax_lines.source_relation = sales_receipts.source_relation
    
    left join tax_rates
        on sales_receipt_tax_lines.tax_rate_id = tax_rates.tax_rate_id
        and sales_receipt_tax_lines.source_relation = tax_rates.source_relation
    
    left join tax_account_join
        on tax_rates.tax_agency_id = tax_account_join.tax_agency_id
        and tax_rates.source_relation = tax_account_join.source_relation
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
        debit_to_account_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        'debit' as transaction_type,
        'sales_receipt' as transaction_source
    from sales_receipt_join

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
        credit_to_account_id as account_id,
        class_id,
        department_id,
        created_at,
        updated_at,
        'credit' as transaction_type,
        'sales_receipt' as transaction_source
    from sales_receipt_join
)

select *
from final
