{% macro get_purchase_tax_line_columns() %}

{% set columns = [
    {"name": "_fivetran_deleted", "datatype": dbt.type_boolean()},
    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "amount", "datatype": dbt.type_float()},
    {"name": "index", "datatype": dbt.type_int()},
    {"name": "net_amount_taxable", "datatype": dbt.type_float()},
    {"name": "override_delta_amount", "datatype": dbt.type_float()},
    {"name": "percent_based", "datatype": dbt.type_boolean()},
    {"name": "purchase_id", "datatype": dbt.type_string()},
    {"name": "tax_inclusive_amount", "datatype": dbt.type_float()},
    {"name": "tax_percent", "datatype": dbt.type_float()},
    {"name": "tax_rate_id", "datatype": dbt.type_string()}
] %}

{{ return(columns) }}

{% endmacro %}