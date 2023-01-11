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
 
cash_flow_types as (

   select cash_flow_key.*,
   {% if var('cash_flow_statement_type_ordinal') %}
       coalesce(account_number_ordinal.cash_flow_type, account_sub_type_ordinal.cash_flow_type, account_type_ordinal.cash_flow_type, account_class_ordinal.cash_flow_type) as cash_flow_type 
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
           end as cash_flow_type
   {% endif %}
   from cash_flow_key
 
   {% if var('cash_flow_statement_type_ordinal') %}

   {% set cash_flow_type_fields = ['account_number', 'account_sub_type', 'account_type', 'account_class'] %}
 
   {% for cash_flow_type_field in cash_flow_type_fields %}       
       left join ordinals as {{ cash_flow_type_field }}_ordinal
           on cash_flow_key.{{ cash_flow_type_field }} = {{ cash_flow_type_field }}_ordinal.{{ cash_flow_type_field }}
   {% endfor %}
 
   {% endif %}
),
 
cash_flow_ordinals as (
 
   select cash_flow_types.*,

   {% if var('cash_flow_statement_type_ordinal') %}
       coalesce(account_number_ordinal.ordinal, account_sub_type_ordinal.ordinal, account_type_ordinal.ordinal, account_class_ordinal.ordinal, cash_flow_type_ordinal.ordinal) as ordinal
   {% else %}
       case when cash_flow_type = 'Cash or Cash Equivalents' then 1
           when cash_flow_type = 'Operating' then 2
           when cash_flow_type  = 'Investing' then 3
           when cash_flow_type  = 'Financing' then 4
       end as ordinal
   {% endif %}

   from cash_flow_types

   {% if var('cash_flow_statement_type_ordinal') %}
 
   {% set ordinal_fields = ['cash_flow_type', 'account_number', 'account_sub_type', 'account_type', 'account_class'] %}
 
   {% for ordinal_field in ordinal_fields %} 
       left join ordinals as {{ ordinal_field }}_ordinal
           on cash_flow_types.{{ ordinal_field }} = {{ ordinal_field }}_ordinal.{{ ordinal_field }}
   {% endfor %}
 
   {% endif %}
)
 
select *
from cash_flow_ordinals

