with cash_flow_classifications as (
 
   select *
   from {{ ref('int_quickbooks__cash_flow_classifications') }}
), 

final as (
    
    select cash_flow_classifications.*,
        lag(cash_ending_period) over (partition by account_id, class_id, source_relation order by cash_flow_period) as cash_beginning_period,
        cash_ending_period - (lag(cash_ending_period) over (partition by account_id, class_id, source_relation order by cash_flow_period)) as cash_net_period
    from cash_flow_classifications
)

select *
from final

