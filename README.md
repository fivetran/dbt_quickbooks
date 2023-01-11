<p align="center">
    <a alt="License"
        href="https://github.com/fivetran/dbt_quickbooks/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" /></a>
    <a alt="Fivetran-Release"
        href="https://fivetran.com/docs/getting-started/core-concepts#releasephases">
        <img src="https://img.shields.io/badge/Fivetran Release Phase-_Beta-orange.svg" /></a>
    <a alt="dbt-core">
        <img src="https://img.shields.io/badge/dbt_Core™_version->=1.3.0_,<2.0.0-orange.svg" /></a>
    <a alt="Maintained?">
        <img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg" /></a>
    <a alt="PRs">
        <img src="https://img.shields.io/badge/Contributions-welcome-blueviolet" /></a>
</p>

# QuickBooks ([docs](https://dbt-quickbooks.netlify.app/))

This package models QuickBooks data from [Fivetran's connector](https://fivetran.com/docs/applications/quickbooks). It uses data in the format described by [this ERD](https://fivetran.com/docs/applications/quickbooks#schemainformation).

The main focus of this package is to provide users insights into their QuickBooks data that can be used for financial statement reporting and deeper analysis. The package achieves this by:
  - Creating a comprehensive general ledger that can be used to create financial statements with additional flexibility.
  - Providing historical general ledger month beginning balances, ending balances, and net change for each account.
  - Enhancing Accounts Payable and Accounts Receivables data by providing past and present aging of bills and invoices.
  - Pairing all expense and sales transactions in one table with accompanying data to provide enhanced analysis.

## Compatibility

> Please be aware that the [dbt_quickbooks](https://github.com/fivetran/dbt_quickbooks) and [dbt_quickbooks_source](https://github.com/fivetran/dbt_quickbooks_source) packages were developed with single currency company data. As such, the package models will not reflect accurate totals if your QuickBooks account has Multi-Currency enabled.

## Models

This package contains transformation models designed to work simultaneously with our [QuickBooks source package](https://github.com/fivetran/dbt_quickbooks_source). A dependency on the source package is declared in this package's `packages.yml` file, so it will automatically download when you run `dbt deps`. The primary outputs of this package are described below. Intermediate models are used to create these output models.

| **model**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [quickbooks__general_ledger](https://github.com/fivetran/dbt_quickbooks/blob/master/models/quickbooks__general_ledger.sql) | Table containing a comprehensive list of all transactions with offsetting debit and credit entries to accounts. |
| [quickbooks__general_ledger_by_period](https://github.com/fivetran/dbt_quickbooks/blob/master/models/quickbooks__general_ledger_by_period.sql) | Table containing the beginning balance, ending balance, and net change of the dollar amount for each month since the first transaction. This table can be used to generate a balance sheet and income statement for your business. |
| [quickbooks__profit_and_loss](https://github.com/fivetran/dbt_quickbooks/blob/master/models/quickbooks__profit_and_loss.sql) | Table containing all revenue and expense account classes by calendar year and month enriched with account type, class, and parent information. |
| [quickbooks__balance_sheet](https://github.com/fivetran/dbt_quickbooks/blob/master/models/quickbooks__balance_sheet.sql) | Table containing all asset, liability, and equity account classes by calendar year and month enriched with account type, class, and parent information. |
| [quickbooks__ap_ar_enhanced](https://github.com/fivetran/dbt_quickbooks/blob/master/models/quickbooks__ap_ar_enhanced.sql) | Table providing the amount, amount paid, due date, and days overdue of all bills and invoices your company has received and paid along with customer, vendor, department, and address information for each invoice or bill. |
| [quickbooks__expenses_sales_enhanced](https://github.com/fivetran/dbt_quickbooks/blob/master/models/quickbooks__expenses_sales.sql) | Table providing enhanced customer, vendor, and account details for each expense and sale transaction. |

## Installation Instructions
Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions, or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.

Include in your `packages.yml`

```yaml
packages:
  - package: fivetran/quickbooks
    version: [">=0.6.0", "<0.7.0"]
```

## Configuration

By default, this package looks for your QuickBooks data in the `quickbooks` schema of your [target database](https://docs.getdbt.com/docs/running-a-dbt-project/using-the-command-line-interface/configure-your-profile). 
If this is not where your QuickBooks data is, add the below configuration to your `dbt_project.yml` file.

```yml
# dbt_project.yml

...
config-version: 2

vars:
    quickbooks_database: your_database_name
    quickbooks_schema: your_schema_name
```

### Union Multiple Quickbooks Connectors
If you have multiple Quickbooks connectors in Fivetran and would like to use this package on all of them simultaneously, we have provided functionality to do so. The package will union all of the data together and pass the unioned table into the transformations. You will be able to see which source it came from in the `source_relation` column of each model. To use this functionality, you will need to set either the `quickbooks_union_schemas` or `quickbooks_union_databases` variables:

```yml
# dbt_project.yml

...
config-version: 2

vars:
    quickbooks_union_schemas: ['quickbooks_usa','quickbooks_canada'] # use this if the data is in different schemas/datasets of the same database/project
    quickbooks_union_databases: ['quickbooks_usa','quickbooks_canada'] # use this if the data is in different databases/projects but uses the same schema name
```

### Customize the ordinal and/or cash flow types for account classes in `dbt_quickbooks` models 
The current default numbering for ordinals is based on best practices for balance sheets and profit-and-loss statements in accounting. You can see these ordinals being implemented in the `quickbooks__general_ledger_by_period` and `quickbooks__cash_flow_classifications` models, then implemented in the `quickbooks__balance_sheet`, `quickbooks__profit_and_loss`, and `quickbooks__cash_flow_statement` models. The ordinals and cash flow types are assigned off of `account_class` values.
 
If you'd like to modify either of these configurations, take the following steps to configure the fields you'd like to modify:

1) Import a csv with fields into the `seeds` folder, then configure either your `financial_statement_ordinal` and/or `cash_flow_statement_type_ordinal` variables in your `dbt_project.yml` to reference the seed file name. 
2) Examine [the `financial_statement_ordinal_example` file](https://github.com/fivetran/dbt_quickbooks/blob/main/integration_tests/seeds/financial_statement_ordinal_example.csv) and/or [the `cash_flow_statement_type_ordinal_example` file](https://github.com/fivetran/dbt_quickbooks/blob/main/integration_tests/seeds/cash_flow_statement_type_ordinal_example.csv) in the `integration_tests/seeds` folder to see what your sample seed file(s) should look like. (NOTE: Make sure that your `seed` file name is different from `financial_statement_ordinal_example`  and `cash_flow_statement_type_ordinal_example` to avoid errors.). You can use these files as an example and follow the steps in (1) to see what the ordering of the data looks like. 
3) When adding and making changes to the seed files, you will need to run the `dbt build` command to compile the updated seed data into the above financial reporting models.

These are our recommended best practices to follow with your seed file (you can see them in action in the `financial_statement_ordinal_example` and `cash_flow_statement_type_ordinal_example` files): 
- REQUIRED: Every row should have a non-null `ordinal` (and for `cash_flow_statement_type_ordinal_example`, `cash_flow_type`) value. 
- REQUIRED: In each row of the seed file, only populate ONE of the columns of `account_class`, `account_type`, `account_sub_type`, and `account_number` to avoid duplicated ordinals and test failures. This should also make the logic cleaner in defining which account value takes precedence in the ordering hierarchy. 
- In `financial_statement_ordinal_example`, we recommend creating ordinals for each `account_class` value available (usually 'Asset', 'Liability', 'Equity' for the Profit and Loss sheet, and 'Revenue' and 'Expense' for the Balance Sheet) to make sure each financial reporting line has an ordinal assigned to it. Then you can create any additional customization as needed with the more specific account fields to order even further. 
- In `financial_statement_ordinal_example`, fill out the `report` field as either `Balance Sheet` if the particular row belongs in `quickbooks__balance_sheet`, `Profit and Loss` for `quickbooks__profit_and_loss`.  
- In `cash_flow_statement_type_ordinal_example`, the `report` field should always be `Cash Flow`.
- In `financial_statement_ordinal_example`, we recommend ordering the `ordinal` for each report separately in the seed, i.e. have ordinals for `quickbooks__balance_sheet` and `quickbooks__profit_and_loss` start at 1 each, to make your reporting more clean. 

### Changing the Build Schema
By default this package will build the QuickBooks staging models within a schema titled (<target_schema> + `_quickbooks_staging`) and QuickBooks final models within a schema titled (<target_schema> + `_quickbooks`) in your target database. If this is not where you would like your modeled QuickBooks data to be written to, add the following configuration to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
models:
    quickbooks:
      +schema: my_new_schema_name # leave blank for just the target_schema
    quickbooks_source:
      +schema: my_new_schema_name # leave blank for just the target_schema
```
### Disabling models

This package takes into consideration that not every QuickBooks account utilizes the same transactional tables, and allows you to disable the corresponding functionality. By default, most variables' values are assumed to be `true` (with exception of purchase orders and credit card payment transactions). Add variables for only the tables you want to disable or enable respectively:

```yml
# dbt_project.yml

...
vars:
  using_address:        false         #disable if you don't have addresses in QuickBooks
  using_bill:           false         #disable if you don't have bills or bill payments in Quickbooks
  using_credit_memo:    false         #disable if you don't have credit memos in Quickbooks
  using_department:     false         #disable if you don't have departments in Quickbooks
  using_deposit:        false         #disable if you don't have deposits in Quickbooks
  using_estimate:       false         #disable if you don't have estimates in Quickbooks
  using_invoice:        false         #disable if you don't have invoices in Quickbooks
  using_invoice_bundle: false         #disable if you don't have invoice bundles in Quickbooks
  using_journal_entry:  false         #disable if you don't have journal entries in Quickbooks
  using_payment:        false         #disable if you don't have payments in Quickbooks
  using_refund_receipt: false         #disable if you don't have refund receipts in Quickbooks
  using_transfer:       false         #disable if you don't have transfers in Quickbooks
  using_vendor_credit:  false         #disable if you don't have vendor credits in Quickbooks
  using_sales_receipt:  false         #disable if you don't have sales receipts in QuickBooks
  using_purchase_order: true          #enable if you want to include purchase orders in your staging models
  using_credit_card_payment_txn: true #enable if you want to include credit card payment transactions in your staging models
```

## Analysis

After running the models within this package, you may want to compare the baseline financial statement totals from the data provided against what you expect. You can make use of the [analysis functionality of dbt](https://docs.getdbt.com/docs/building-a-dbt-project/analyses/) and run pre-written SQL to test these values. The SQL files within the [analysis](https://github.com/fivetran/dbt_quickbooks/blob/master/analysis) folder contain SQL queries you may compile to generate balance sheet and income statement values. You can then tie these generated values to your expected ones and confirm the values provided in this package are accurate.

## Contributions

Don't see a model or specific metric you would have liked to be included? Notice any bugs when installing 
and running the package? If so, we highly encourage and welcome contributions to this package! 
Please create issues or open PRs against `main`. Check out [this post](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package.

## Database Support

This package has been tested on BigQuery, Snowflake, Redshift, and Postgres.

## Resources:
- Provide [feedback](https://www.surveymonkey.com/r/DQ7K7WW) on our existing dbt packages or what you'd like to see next
- Have questions or feedback, or need help? Book a time during our office hours [here](https://calendly.com/fivetran-solutions-team/fivetran-solutions-team-office-hours) or shoot us an email at solutions@fivetran.com.
- Find all of Fivetran's pre-built dbt packages in our [dbt hub](https://hub.getdbt.com/fivetran/)
- Learn how to orchestrate your models with [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt)
- Learn more about Fivetran overall [in our docs](https://fivetran.com/docs)
- Check out [Fivetran's blog](https://fivetran.com/blog)
- Learn more about dbt [in the dbt docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](http://slack.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the dbt blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
