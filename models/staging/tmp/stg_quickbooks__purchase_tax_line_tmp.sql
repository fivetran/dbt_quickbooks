--To enable this model, set both the quickbooks__tax_lines_enabled and using_purchase_tax_line variables within your dbt_project.yml file to True.
{{ config(enabled=var('quickbooks__tax_lines_enabled', False) and var('using_purchase_tax_line', False)) }}

{% if var('quickbooks_union_schemas', []) | length > 0 or var('quickbooks_union_databases', []) | length > 0 %}

{{
    fivetran_utils.union_data(
        table_identifier='purchase_tax_line', 
        database_variable='quickbooks_database', 
        schema_variable='quickbooks_schema', 
        default_database=target.database,
        default_schema='quickbooks',
        default_variable='purchase_tax_line',
        union_schema_variable='quickbooks_union_schemas',
        union_database_variable='quickbooks_union_databases'
    )
}}

{% else %}

{{
    fivetran_utils.union_connections(
        connection_dictionary='quickbooks_sources',
        single_source_name='quickbooks',
        single_table_name='purchase_tax_line'
    )
}}

{% endif %}