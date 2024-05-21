/*
Table that creates a debit record to the specified expense account and credit record to accounts payable for each bill transaction.
*/

--To disable this model, set the using_bill variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_bill', True)) }}

with bills as (

    select *
    from {{ ref('stg_quickbooks__bill') }}
),

bill_lines as (

    select *
    from {{ ref('stg_quickbooks__bill_line') }}
),

global_tax_account as (

    select *
    from {{ ref('stg_quickbooks__account') }}
    where account_sub_type = 'GlobalTaxPayable'
),

items as (

    select
        item.*,
        parent.expense_account_id as parent_expense_account_id,
        parent.income_account_id as parent_income_account_id
    from {{ ref('stg_quickbooks__item') }} item

    left join {{ ref('stg_quickbooks__item') }} parent
        on item.parent_item_id = parent.item_id
        and item.source_relation = parent.source_relation
),

bill_join as (
    select
        bills.bill_id as transaction_id,
        bills.source_relation,
        bills.total_amount,
        bills.global_tax_calculation,
        bill_lines.index,
        bills.transaction_date,
        bill_lines.amount,
        coalesce(bill_lines.account_expense_account_id,items.asset_account_id, items.expense_account_id, items.parent_expense_account_id, items.expense_account_id, items.parent_income_account_id, items.income_account_id) as payed_to_account_id,
        bills.payable_account_id,
        coalesce(bill_lines.account_expense_customer_id, bill_lines.item_expense_customer_id) as customer_id,
        coalesce(bill_lines.item_expense_class_id, bill_lines.account_expense_class_id) as class_id,
        bills.vendor_id,
        bills.department_id
    from bills

    inner join bill_lines
        on bills.bill_id = bill_lines.bill_id
        and bills.source_relation = bill_lines.source_relation

    left join items
        on bill_lines.item_expense_item_id = items.item_id
        and bill_lines.source_relation = items.source_relation
),

global_tax_filter as (
    select 
        transaction_id,  
        transaction_date,
        global_tax_calculation,
        total_amount,
        payable_account_id,
        vendor_id,
        department_id,
        source_relation,
        sum(amount) as total_line_amount
    from bill_join
    where global_tax_calculation = 'TaxInclusive'
    group by 1,2,3,4,5,6,7,8

),

final as (
    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        vendor_id,
        amount,
        payed_to_account_id as account_id,
        class_id,
        department_id,
        'debit' as transaction_type,
        'bill' as transaction_source
    from bill_join

    union all

    select
        transaction_id,
        source_relation,
        index,
        transaction_date,
        customer_id,
        vendor_id,
        amount,
        payable_account_id as account_id,
        class_id,
        department_id,
        'credit' as transaction_type,
        'bill' as transaction_source
    from bill_join

    union all

    select
        global_tax_filter.transaction_id,
        global_tax_filter.source_relation,
        -1 as index,
        global_tax_filter.transaction_date,
        null as customer_id,
        global_tax_filter.vendor_id,  
        (global_tax_filter.total_amount - global_tax_filter.total_line_amount) as amount,
        global_tax_account.account_id as account_id,
        null as class_id,
        global_tax_filter.department_id,
        'debit' as transaction_type,
        'bill' as transaction_source
    from global_tax_filter
    left join global_tax_account
        on global_tax_filter.source_relation = global_tax_account.source_relation
    where global_tax_filter.total_amount > global_tax_filter.total_line_amount

    union all

    select
        global_tax_filter.transaction_id,
        global_tax_filter.source_relation,
        -2 as index,
        global_tax_filter.transaction_date,
        null as customer_id,
        global_tax_filter.vendor_id,  
        (global_tax_filter.total_amount - global_tax_filter.total_line_amount) as amount,
        global_tax_filter.payable_account_id as account_id,
        null as class_id,
        global_tax_filter.department_id,
        'credit' as transaction_type,
        'bill' as transaction_source
    from global_tax_filter
    left join global_tax_account
        on global_tax_filter.source_relation = global_tax_account.source_relation
    where global_tax_filter.total_amount > global_tax_filter.total_line_amount
)

select *
from final
