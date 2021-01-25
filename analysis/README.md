# QuickBooks Analysis
> Note: The compiled sql within the analysis folder references the final model [quickbooks__general_ledger_by_period](https://github.com/fivetran/dbt_quickbooks/blob/master/models/quickbooks__general_ledger_by_period.sql). As such, prior to 
compiling the provided sql to test financial statement accuracy, you must first execute `dbt run`.

The Fivetran dbt package was designed to provide users insights into their QuickBooks data that can be used for financial statement reporting and deeper analysis. 
While our aim of this package is to allow users to gain additional insights on top of their base financial statements, it is also imperative that base financial
metrics are accurate before being comfortable to search for deeper analysis. As such, if you would like to check your baseline Balance Sheet and Income Statement
values prior to using this package, we encourage you to use the compiled sql provided in the `analysis` directory.

## Analysis SQL
| **sql**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [quickbooks__balance_sheet](https://github.com/fivetran/dbt_quickbooks/blob/master/analysis/quickbooks__balance_sheet.sql) | The output of the compiled sql will generate three records: Assets, Liabilities, Equity. The SQL command references the quickbooks__general_ledger_by_period model and pulls all balance sheet account ending balances as of the most recent transaction month. These balances are then added for each respective balance sheet type. This will ensure your total balance sheet balances ties to what you expect. |
| [quickbooks__income_statement](https://github.com/fivetran/dbt_quickbooks/blob/master/analysis/quickbooks__income_statement.sql) | The output of the compiled sql will generate two records: Revenue, Expense. The SQL command references the quickbooks__general_ledger_by_period model and sums all period net change for Revenue and Expense accounts respectively. **Note**: you will need to set the date range in order to generate an accurate revenue and expense totals for your defined time period. |

## SQL Compile Instructions
Leveraging the above sql is made possible by the [analysis functionality of dbt](https://docs.getdbt.com/docs/building-a-dbt-project/analyses/). In order to
compile the sql, you will perform the following steps:
- Execute `dbt run` to create the package models.
- Execute `dbt compile` to generate the target specific sql.
- Navigate to your project's `/target/compiled/quickbooks/analysis` directory.
- Copy the `quickbooks__balance_sheet` code and run in your data warehouse.
- Confirm the balance sheet totals match your expected results.
- Copy the `quickbooks__income_statement` code and run in your data warehouse.
- Confirm the income statement totals match your expected results.

## Contributions
Don't see a compiled sql statement you would have liked to be included? Notice any bugs when compiling
and running the analysis sql? If so, we highly encourage and welcome contributions to this package! 
Please create issues or open PRs against `master`. Check out [this post](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package.

## Database Support
This package has been tested on BigQuery, Snowflake and Redshift.

## Resources:
- Provide [feedback](https://www.surveymonkey.com/r/DQ7K7WW) on our existing dbt packages or what you'd like to see next
- Have questions or feedback, or need help? Book a time during our office hours [here](https://calendly.com/fivetran-solutions-team/fivetran-solutions-team-office-hours) or shoot us an email at solutions@fivetran.com
- Find all of Fivetran's pre-built dbt packages in our [dbt hub](https://hub.getdbt.com/fivetran/)
- Learn how to orchestrate dbt transformations with Fivetran [here](https://fivetran.com/docs/transformations/dbt)
- Learn more about Fivetran overall [in our docs](https://fivetran.com/docs)
- Check out [Fivetran's blog](https://fivetran.com/blog)
- Learn more about dbt [in the dbt docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](http://slack.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the dbt blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices