with cash_flow_classifications as (

    select *
    from {{ ref('int_quickbooks__cash_flow_classifications') }}
), 

final as (
    
    select cash_flow_classifications.*,
        coalesce(lag(cash_ending_period) over (partition by account_id, class_id, source_relation 
            order by source_relation, cash_flow_period), 0) as cash_beginning_period,
        cash_ending_period - coalesce(lag(cash_ending_period) over (partition by account_id, class_id, source_relation 
            order by source_relation, cash_flow_period), 0) as cash_net_period,
        coalesce(lag(cash_converted_ending_period) over (partition by account_id, class_id, source_relation 
            order by source_relation, cash_flow_period), 0) as cash_converted_beginning_period, 
        cash_converted_ending_period - coalesce(lag(cash_converted_ending_period) over (partition by account_id, class_id, source_relation 
            order by source_relation, cash_flow_period), 0) as cash_converted_net_period
    from cash_flow_classifications
)

select *
from final

