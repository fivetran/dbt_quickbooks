{{ config(enabled=var('using_sales_receipt_tax_line', False)) }}

{{
    fivetran_utils.union_data(
        table_identifier='sales_receipt_tax_line', 
        database_variable='quickbooks_database', 
        schema_variable='quickbooks_schema', 
        default_database=target.database,
        default_schema='quickbooks',
        default_variable='sales_receipt_tax_line',
        union_schema_variable='quickbooks_union_schemas',
        union_database_variable='quickbooks_union_databases'
    )
}}