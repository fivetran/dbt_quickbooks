{%- set enhanced_relations = {
    'int_quickbooks__expenses_union': 'enabled',
    'int_quickbooks__sales_union': 'enabled' if fivetran_utils.enabled_vars_one_true(['using_sales_receipt', 'using_invoice']) else 'disabled'
} -%}

{%- set enhanced_columns = {
    'transaction_source': dbt.type_string(),
    'transaction_id': dbt.type_string(),
    'source_relation': dbt.type_string(),
    'transaction_line_id': dbt.type_int(),
    'doc_number': dbt.type_string(),
    'transaction_type': dbt.type_string(),
    'transaction_date': 'date',
    'item_id': dbt.type_string(),
    'item_quantity': dbt.type_float(),
    'item_unit_price': dbt.type_float(),
    'account_id': dbt.type_string(),
    'account_name': dbt.type_string(),
    'account_sub_type': dbt.type_string(),
    'account_number': dbt.type_string(),
    'parent_account_number': dbt.type_string(),
    'class_id': dbt.type_string(),
    'department_id': dbt.type_string()
} -%}
{%- do enhanced_columns.update({'department_name': dbt.type_string()}) if var('using_department', True) -%}
{%- do enhanced_columns.update({
    'customer_id': dbt.type_string(),
    'customer_name': dbt.type_string(),
    'customer_website': dbt.type_string()
}) -%}
{%- do enhanced_columns.update({'customer_type_name': dbt.type_string()}) if var('using_customer_type', True) -%}
{%- do enhanced_columns.update({
    'vendor_id': dbt.type_string(),
    'vendor_name': dbt.type_string(),
    'billable_status': dbt.type_string(),
    'description': dbt.type_string(),
    'amount': dbt.type_float(),
    'converted_amount': dbt.type_float(),
    'total_amount': dbt.type_float(),
    'total_converted_amount': dbt.type_float()
}) -%}

with final as (
    {{ explicit_union(enhanced_relations, enhanced_columns) }}
)

select *
from final
