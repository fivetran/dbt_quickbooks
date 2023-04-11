with cash_flow_key as (
 
   select calendar_date as cash_flow_period,
       source_relation,
       account_class,
       class_id,
       is_sub_account,
       parent_account_number,
       parent_account_name,
       account_type,
       account_sub_type,
       account_number,
       account_id,
       account_name,
       amount as cash_ending_period,
       {{ dbt_utils.generate_surrogate_key(['account_id', 'source_relation', 'calendar_date', 'class_id']) }} as account_unique_id
   from {{ ref('quickbooks__balance_sheet') }}
),
 
{% if var('cash_flow_statement_type_ordinal') %}
ordinals as (
 
   select
       cast(account_class as {{ dbt.type_string() }}) as account_class,
       cast(account_type as {{ dbt.type_string() }}) as account_type,
       cast(account_sub_type as {{ dbt.type_string() }}) as account_sub_type,
       cast(account_number as {{ dbt.type_string() }}) as account_number,
       cast(cash_flow_type as {{ dbt.type_string() }}) as cash_flow_type,
       ordinal
   from {{ var('cash_flow_statement_type_ordinal') }}
),
{% endif %}
 
cash_flow_types_and_ordinals as (

   select cash_flow_key.*,
   {% if var('cash_flow_statement_type_ordinal') %}
       coalesce(account_number_ordinal.cash_flow_type, account_sub_type_ordinal.cash_flow_type, account_type_ordinal.cash_flow_type, account_class_ordinal.cash_flow_type) as cash_flow_type,
       coalesce(account_number_ordinal.ordinal, account_sub_type_ordinal.ordinal, account_type_ordinal.ordinal, account_class_ordinal.ordinal) as cash_flow_ordinal 
   {% else %}
       case when account_type = 'Bank' then 'Cash or Cash Equivalents'
           when account_type = 'Accounts Receivable' then 'Operating'
           when account_type = 'Credit Card' then 'Operating'
           when account_type = 'Other Current Asset' then 'Operating'
           when account_type = 'Accounts Payable' then 'Operating'
           when account_type = 'Other Current Liability' then 'Operating'
           when account_name = 'Net Income Adjustment' then 'Operating'
           when account_type = 'Fixed Asset' then 'Investing'
           when account_type = 'Other Asset' then 'Investing'
           when account_type = 'Long Term Liability' then 'Financing'
           when account_class = 'Equity' then 'Financing'
        end as cash_flow_type,
        case when account_type = 'Bank' then 1
           when account_type = 'Accounts Receivable' then 2
           when account_type = 'Credit Card' then 2
           when account_type = 'Other Current Asset' then 2
           when account_type = 'Accounts Payable' then 2
           when account_type = 'Other Current Liability' then 2
           when account_name = 'Net Income Adjustment' then 2
           when account_type = 'Fixed Asset' then 3
           when account_type = 'Other Asset' then 3
           when account_type = 'Long Term Liability' then 4
           when account_class = 'Equity' then 4
        end as cash_flow_ordinal
    {% endif %}

   from cash_flow_key
 
   {% if var('cash_flow_statement_type_ordinal') %}

   {% set cash_flow_type_fields = ['account_number', 'account_sub_type', 'account_type', 'account_class'] %}
 
   {% for cash_flow_type_field in cash_flow_type_fields %}       
       left join ordinals as {{ cash_flow_type_field }}_ordinal
           on cash_flow_key.{{ cash_flow_type_field }} = {{ cash_flow_type_field }}_ordinal.{{ cash_flow_type_field }}
   {% endfor %}
 
   {% endif %}
)

select *
from cash_flow_types_and_ordinals

