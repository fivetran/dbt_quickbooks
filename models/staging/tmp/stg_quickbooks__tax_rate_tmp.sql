{{ config(enabled=var('using_tax_rate', False)) }}

{{
    fivetran_utils.union_data(
        table_identifier='tax_rate', 
        database_variable='quickbooks_database', 
        schema_variable='quickbooks_schema', 
        default_database=target.database,
        default_schema='quickbooks',
        default_variable='tax_rate',
        union_schema_variable='quickbooks_union_schemas',
        union_database_variable='quickbooks_union_databases'
    )
}}