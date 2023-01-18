{% docs account_class %}
Class of the account associated
{% enddocs %}

{% docs account_id %}
The identifier of the account associated
{% enddocs %}

{% docs account_name %}
Name of the account associated
{% enddocs %}

{% docs account_number %}
User defined number of the account.
{% enddocs %}

{% docs account_ordinal %}
Integer value to order the account within final financial statement reporting. The customer can also configure the ordinal; [see the README for details](https://github.com/fivetran/dbt_quickbooks/blob/main/README.md#customize-the-account-ordering-of-your-profit-loss-and-balance-sheet-models)
{% enddocs %}

{% docs account_sub_type %}
Sub type of the account associated
{% enddocs %}

{% docs account_type %}
The type of account associated
{% enddocs %}

{% docs calendar_date %}
Timestamp of the first calendar date of the month.
{% enddocs calendar_date %}

{% docs class_id %}
Reference to the class associated
{% enddocs %}

{% docs is_sub_account %}
Boolean indicating whether the account is a sub account (true) or a parent account (false).
{% enddocs %}

{% docs parent_account_name %}
The parent account name. If the account is the parent account then the account name is recorded.
{% enddocs %}

{% docs parent_account_number %}
The parent account number. If the account is the parent account then the account number is recorded.
{% enddocs %}

{% docs transaction_date %}
Timestamp of the date that the transaction occurred.
{% enddocs %}

{% docs transaction_id %}
Unique identifier of the transaction
{% enddocs %}
