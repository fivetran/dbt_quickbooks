

with unioned_models_prod as (

    {{ dbt_utils.union_relations(
        quickbooks.get_enabled_unioned_models(target.schema ~ '_quickbooks_prod')
    ) }}
),

unioned_models_dev as (

    {{ dbt_utils.union_relations(
        quickbooks.get_enabled_unioned_models(target.schema ~ '_quickbooks_dev')
    ) }}
),

accounts_prod as (

    select *
    from {{ target.schema }}_quickbooks_prod.int_quickbooks__account_classifications
),

accounts_dev as (

    select *
    from {{ target.schema }}_quickbooks_dev.int_quickbooks__account_classifications
),

general_ledger_prod as (

    select  
        unioned_models_prod.transaction_id,
        unioned_models_prod.source_relation,
        unioned_models_prod.index as transaction_index,
        unioned_models_prod.account_id,
        unioned_models_prod.transaction_type,
        unioned_models_prod.transaction_source,
        sum(case when accounts_prod.transaction_type = unioned_models_prod.transaction_type
                then unioned_models_prod.amount 
                else unioned_models_prod.amount * -1 end) as adjusted_amount_prod,
        sum(case when accounts_prod.transaction_type = unioned_models_prod.transaction_type
                then unioned_models_prod.converted_amount
                else unioned_models_prod.converted_amount * -1 end) as adjusted_converted_amount_prod
    from unioned_models_prod

    left join accounts_prod
        on unioned_models_prod.account_id = accounts_prod.account_id
        and unioned_models_prod.source_relation = accounts_prod.source_relation
    
    group by 1, 2, 3, 4, 5, 6
),

general_ledger_dev as (

    select  
        unioned_models_dev.transaction_id,
        unioned_models_dev.source_relation,
        unioned_models_dev.index as transaction_index,
        unioned_models_dev.account_id,
        unioned_models_dev.transaction_type,
        unioned_models_dev.transaction_source,
        sum(case when accounts_dev.transaction_type = unioned_models_dev.transaction_type
                then unioned_models_dev.amount 
                else unioned_models_dev.amount * -1 end) as adjusted_amount_dev,
        sum(case when accounts_dev.transaction_type = unioned_models_dev.transaction_type
                then unioned_models_dev.converted_amount
                else unioned_models_dev.converted_amount * -1 end) as adjusted_converted_amount_dev
    from unioned_models_dev

    left join accounts_dev
        on unioned_models_dev.account_id = accounts_dev.account_id
        and unioned_models_dev.source_relation = accounts_dev.source_relation
    
    group by 1, 2, 3, 4, 5, 6
),

match_check as (

    select 
        coalesce(general_ledger_prod.transaction_id, general_ledger_dev.transaction_id) as transaction_id,
        coalesce(general_ledger_prod.source_relation, general_ledger_dev.source_relation) as source_relation,
        coalesce(general_ledger_prod.transaction_index, general_ledger_dev.transaction_index) as transaction_index,
        coalesce(general_ledger_prod.account_id, general_ledger_dev.account_id) as account_id, 
        coalesce(general_ledger_prod.transaction_type, general_ledger_dev.transaction_type) as transaction_type,
        coalesce(general_ledger_prod.transaction_source, general_ledger_dev.transaction_source) as transaction_source,
        general_ledger_prod.adjusted_amount_prod,
        general_ledger_prod.adjusted_converted_amount_prod,
        general_ledger_dev.adjusted_amount_dev,
        general_ledger_dev.adjusted_converted_amount_dev
    from general_ledger_prod
    full outer join general_ledger_dev
        on general_ledger_prod.transaction_id = general_ledger_dev.transaction_id
        and general_ledger_prod.source_relation = general_ledger_dev.source_relation
        and general_ledger_prod.transaction_index = general_ledger_dev.transaction_index
        and general_ledger_prod.account_id = general_ledger_dev.account_id
        and general_ledger_prod.transaction_type = general_ledger_dev.transaction_type
        and general_ledger_prod.transaction_source = general_ledger_dev.transaction_source
)

select *
from match_check
where abs(adjusted_amount_prod - adjusted_amount_dev) >= 0.01
or abs(adjusted_converted_amount_prod - adjusted_converted_amount_dev) >= 0.01