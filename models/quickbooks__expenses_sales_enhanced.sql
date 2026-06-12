{%- set enhanced_relations = {
    'int_quickbooks__expenses_union': 'enabled',
    'int_quickbooks__sales_union': 'enabled' if fivetran_utils.enabled_vars_one_true(['using_sales_receipt', 'using_invoice']) else 'disabled'
} -%}

{%- set enhanced_columns = [
    'transaction_source',
    'transaction_id',
    'source_relation',
    'transaction_line_id',
    'doc_number',
    'transaction_type',
    'transaction_date',
    'item_id',
    'item_quantity',
    'item_unit_price',
    'account_id',
    'account_name',
    'account_sub_type',
    'account_number',
    'parent_account_number',
    'class_id',
    'department_id'
] -%}
{%- do enhanced_columns.extend(['department_name']) if var('using_department', True) -%}
{%- do enhanced_columns.extend(['customer_id', 'customer_name', 'customer_website']) -%}
{%- do enhanced_columns.extend(['customer_type_name']) if var('using_customer_type', True) -%}
{%- do enhanced_columns.extend([
    'vendor_id',
    'vendor_name',
    'billable_status',
    'description',
    'amount',
    'converted_amount',
    'total_amount',
    'total_converted_amount'
]) -%}

with final as (
    {{ explicit_union(enhanced_relations, enhanced_columns) }}
)

select *
from final
