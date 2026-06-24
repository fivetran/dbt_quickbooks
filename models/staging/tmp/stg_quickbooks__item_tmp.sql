{% if var('quickbooks_union_schemas', []) | length > 0 or var('quickbooks_union_databases', []) | length > 0 %}

{{
    fivetran_utils.union_data(
        table_identifier='item', 
        database_variable='quickbooks_database', 
        schema_variable='quickbooks_schema', 
        default_database=target.database,
        default_schema='quickbooks',
        default_variable='item',
        union_schema_variable='quickbooks_union_schemas',
        union_database_variable='quickbooks_union_databases'
    )
}}

{% else %}

{{
    fivetran_utils.union_connections(
        connection_dictionary='quickbooks_sources',
        single_source_name='quickbooks',
        single_table_name='item'
    )
}}

{% endif %}