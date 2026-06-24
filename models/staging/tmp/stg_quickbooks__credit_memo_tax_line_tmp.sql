--To enable this model, set the using_tax_lines variable within your dbt_project.yml file to True.
{{ config(enabled=var('using_tax_lines', False)) }}

{{
    fivetran_utils.union_data(
        table_identifier='credit_memo_tax_line_detail',
        database_variable='quickbooks_database',
        schema_variable='quickbooks_schema',
        default_database=target.database,
        default_schema='quickbooks',
        default_variable='credit_memo_tax_line_detail',
        union_schema_variable='quickbooks_union_schemas',
        union_database_variable='quickbooks_union_databases'
    )
}}
