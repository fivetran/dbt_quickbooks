--To enable this model, set the using_tax_lines variable within your dbt_project.yml file to True.
{{ config(enabled=var('using_tax_lines', False)) }}

{{
    fivetran_utils.union_data(
        table_identifier='deposit_tax_line_detail',
        database_variable='quickbooks_database',
        schema_variable='quickbooks_schema',
        default_database=target.database,
        default_schema='quickbooks',
        default_variable='deposit_tax_line_detail',
        union_schema_variable='quickbooks_union_schemas',
        union_database_variable='quickbooks_union_databases'
    )
}}
