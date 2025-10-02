--To disable this model, set the using_purchase_tax_line variable within your dbt_project.yml file to False.
{{ config(enabled=var('using_purchase_tax_line', False)) }}

with base as (

    select * 
    from {{ ref('stg_quickbooks__purchase_tax_line_tmp') }}
),

fields as ( 

    select
        /*
        The below macro is used to generate the correct SQL for package staging models. It takes a list of columns 
        that are expected/needed (staging_columns from dbt_quickbooks_source/models/tmp/) and compares it with columns 
        in the source (source_columns from dbt_quickbooks_source/macros/).
        For more information refer to our dbt_fivetran_utils documentation (https://github.com/fivetran/dbt_fivetran_utils.git).
        */

        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_quickbooks__purchase_tax_line_tmp')),
                staging_columns=get_purchase_tax_line_columns()
            )
        }}

        {{ 
            fivetran_utils.source_relation(
                union_schema_variable='quickbooks_union_schemas', 
                union_database_variable='quickbooks_union_databases'
                ) 
        }}

    from base
),

final as (

    select
        cast(purchase_id as {{ dbt.type_string() }}) as purchase_id,
        cast(tax_rate_id as {{ dbt.type_string() }}) as tax_rate_id,
        amount,
        index,
        net_amount_taxable,
        override_delta_amount,
        percent_based,
        tax_inclusive_amount,
        tax_percent,
        source_relation,
        _fivetran_deleted
    from fields
)

select *
from final
where not coalesce(_fivetran_deleted, false)