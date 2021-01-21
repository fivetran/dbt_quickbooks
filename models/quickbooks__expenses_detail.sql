--To disable this model, set the using_purchase variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_purchase', True)) }}

with expense_union as (
    select *
    from {{ ref('int_quickbooks__purchase_transactions') }}

    {% if var('using_bill', True) %}
    union all

    select *
    from {{ ref('int_quickbooks__bill_transactions') }}
    {% endif %} 

    {% if var('using_journal_entry', True) %}
    union all

    select *
    from {{ ref('int_quickbooks__journal_entry_transactions') }}
    {% endif %} 

    {% if var('using_deposit', True) %}
    union all

    select *
    from {{ ref('int_quickbooks__deposit_transactions') }}
    {% endif %} 
),

customers as (
    select *
    from {{ ref('stg_quickbooks__customer') }}
),

{% if var('using_department', True) %}
departments as ( 
    select *
    from {{ ref('stg_quickbooks__department') }}
),
{% endif %}

vendors as (
    select *
    from {{ ref('stg_quickbooks__vendor') }}
),

expense_accounts as (
    select *
    from {{ ref('int_quickbooks__account_classifications') }}
    where account_type = 'Expense'
),

final as (
    select 
        expense_union.transaction_id,
        expense_union.transaction_line_id,
        expense_union.transaction_type,
        expense_union.transaction_date,
        expense_union.account_id,
        expense_accounts.name as account_name,
        expense_accounts.account_sub_type as account_sub_type,
        expense_union.class_id,
        expense_union.department_id,
        {% if var('using_department', True) %}
        departments.fully_qualified_name as department_name,
        {% endif %}
        expense_union.customer_id,
        customers.fully_qualified_name as customer_name,
        expense_union.vendor_id,
        vendors.display_name as vendor_name,
        expense_union.billable_status,
        expense_union.description,
        expense_union.amount,
        expense_union.total_amount

    from expense_union

    inner join expense_accounts
        on expense_union.account_id = expense_accounts.account_id

    left join customers
        on customers.customer_id = expense_union.customer_id

    left join vendors
        on vendors.vendor_id = expense_union.vendor_id

    {% if var('using_department', True) %}
    left join departments
        on departments.department_id = expense_union.department_id
    {% endif %}
)

select *
from final