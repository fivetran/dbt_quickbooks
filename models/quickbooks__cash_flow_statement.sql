with cash_flow_classifications as (
 
   select *
   from {{ ref('quickbooks__cash_flow_classifications') }}
),
 
cash_flow_index as (
   select cash_flow_classifications.*,
        row_number() over (partition by account_unique_id order by calendar_date) as account_period
   from cash_flow_classifications
),
 
final as (
 
select *,
   lag(cash_ending_period) over (partition by account_unique_id order by account_period) as cash_beginning_period,
   lag(cash_ending_period) over (partition by account_unique_id order by account_period) - cash_ending_period as cash_net_period
 from cash_flow_index
)
select *
from final

