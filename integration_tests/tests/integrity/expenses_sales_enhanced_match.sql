
{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

with expenses_sales_source as (

    select distinct
        transaction_id, 
        transaction_line_id, 
        source_relation,
        item_id
    from {{ ref('int_quickbooks__sales_union') }}

    union all

    select distinct
        transaction_id, 
        transaction_line_id, 
        source_relation,
        item_id
    from {{ ref('int_quickbooks__expenses_union') }}
),

expenses_sales_end as (

    select distinct
        transaction_id, 
        transaction_line_id, 
        source_relation,
        item_id
    from {{ ref('quickbooks__expenses_sales_enhanced') }}
),


source_not_in_end as (
    -- rows from prod not found in dev
    select * from expenses_sales_source
    except distinct
    select * from expenses_sales_end
),

end_not_in_source as (
    -- rows from dev not found in prod
    select * from expenses_sales_end
    except distinct
    select * from expenses_sales_source
),

final as (
    select
        *,
        'from prod' as source
    from source_not_in_end

    union all -- union since we only care if rows are produced

    select
        *,
        'from dev' as source
    from end_not_in_source
)

select *
from final