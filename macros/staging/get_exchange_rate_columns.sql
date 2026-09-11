{% macro get_exchange_rate_columns() %}

{% set columns = [
    {"name": "as_of_date", "datatype": "date"},
    {"name": "source_currency_code", "datatype": dbt.type_string()},
    {"name": "target_currency_code", "datatype": dbt.type_string()},
    {"name": "rate", "datatype": dbt.type_float()},
    {"name": "created_at", "datatype": dbt.type_timestamp()},
    {"name": "updated_at", "datatype": dbt.type_timestamp()},
    {"name": "_fivetran_deleted", "datatype": "boolean"}
] %}

{{ return(columns) }}

{% endmacro %}
