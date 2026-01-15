<!--section="quickbooks_transformation_model"-->
# Quickbooks dbt Package

<p align="left">
    <a alt="License"
        href="https://github.com/fivetran/dbt_quickbooks/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" /></a>
    <a alt="dbt-core">
        <img src="https://img.shields.io/badge/dbt_Core™_version->=1.3.0,_<3.0.0-orange.svg" /></a>
    <a alt="Maintained?">
        <img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg" /></a>
    <a alt="PRs">
        <img src="https://img.shields.io/badge/Contributions-welcome-blueviolet" /></a>
    <a alt="Fivetran Quickstart Compatible"
        href="https://fivetran.com/docs/transformations/data-models/quickstart-management#quickstartmanagement">
        <img src="https://img.shields.io/badge/Fivetran_Quickstart_Compatible%3F-yes-green.svg" /></a>
</p>

This dbt package transforms data from Fivetran's Quickbooks connector into analytics-ready tables.

## Resources

- Number of materialized models¹: 108
- Connector documentation
  - [Quickbooks connector documentation](https://fivetran.com/docs/connectors/applications/quickbooks)
  - [Quickbooks ERD](https://fivetran.com/docs/connectors/applications/quickbooks#schemainformation)
- dbt package documentation
  - [GitHub repository](https://github.com/fivetran/dbt_quickbooks)
  - [dbt Docs](https://fivetran.github.io/dbt_quickbooks/#!/overview)
  - [DAG](https://fivetran.github.io/dbt_quickbooks/#!/overview?g_v=1)
  - [Changelog](https://github.com/fivetran/dbt_quickbooks/blob/main/CHANGELOG.md)

## What does this dbt package do?
This package enables you to create comprehensive financial statements, analyze accounts payable and receivable aging, and track detailed transaction histories. It creates enriched models with metrics focused on general ledger analysis, financial reporting, and cash flow management.

### Output schema
Final output tables are generated in the following target schema:

```
<your_database>.<connector/schema_name>_quickbooks
```

### Final output tables

By default, this package materializes the following final tables:

| Table | Description |
| :---- | :---- |
| [quickbooks__general_ledger](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__general_ledger) | Complete transaction-level view showing every debit and credit entry with running account balances, perfect for detailed financial analysis and audit trails. <br><br>**Example Analytics Questions:**<br><ul><li>Which accounts show consistent growth patterns that indicate successful business strategies?</li><li>What transaction patterns and account behaviors provide the clearest operational insights?</li></ul> |
| [quickbooks__general_ledger_by_period](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__general_ledger_by_period) | Monthly account balance summary showing beginning balances, ending balances, and net changes for each account, ideal for generating financial statements and tracking account performance over time. <br><br>**Example Analytics Questions:**<br><ul><li>Which accounts demonstrate the strongest month-over-month improvement and growth momentum?</li><li>What seasonal patterns and cyclical trends can inform better financial planning and budgeting?</li></ul> |
| [quickbooks__profit_and_loss](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__profit_and_loss) | Income statement view showing revenue and expense accounts by month and year, with configurable ordering for professional financial reporting. <br><br>**Example Analytics Questions:**<br><ul><li>Which revenue streams and cost optimizations are driving the strongest profit growth?</li><li>What expense-to-revenue ratios and margin trends provide the clearest profitability insights?</li></ul> |
| [quickbooks__balance_sheet](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__balance_sheet) | Balance sheet view displaying assets, liabilities, and equity accounts by month and year, organized for standard financial statement presentation. <br><br>**Example Analytics Questions:**<br><ul><li>Which asset investments are generating the strongest returns and should be expanded?</li><li>What debt-to-equity ratios and financial leverage trends indicate optimal capital structure?</li></ul> |
| [quickbooks__cash_flow_statement](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__cash_flow_statement) | Cash flow statement showing operating, investing, and financing activities with beginning/ending cash positions and net changes by period. **IMPORTANT**: You will likely need to configure cash flow types for your specific use case. <br><br>**Example Analytics Questions:**<br><ul><li>Which operational improvements are generating the strongest positive cash flow trends?</li><li>What seasonal cash flow patterns and financing needs can inform strategic planning?</li></ul> |
| [quickbooks__ap_ar_enhanced](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__ap_ar_enhanced) | Accounts payable and receivable aging report showing outstanding bills and invoices with payment history, due dates, and overdue analysis for cash flow management. <br><br>**Example Analytics Questions:**<br><ul><li>Which customers have the best payment patterns and deserve credit limit increases or early payment discounts?</li><li>What payment timing patterns and customer behavior trends can optimize cash flow forecasting?</li></ul> |
| [quickbooks__expenses_sales_enhanced](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__expenses_sales_enhanced) | Unified view of all expense and sales transactions with enriched customer, vendor, department, and product details for comprehensive revenue and cost analysis. <br><br>**Example Analytics Questions:**<br><ul><li>Which customer segments and product lines deliver the highest margins and growth potential?</li><li>What departmental spending patterns and vendor relationships provide the best cost optimization opportunities?</li></ul> |

¹ Each Quickstart transformation job run materializes these models if all components of this data model are enabled. This count includes all staging, intermediate, and final models materialized as `view`, `table`, or `incremental`.

---

### Multicurrency Support

> This package now supports multicurrency by bringing in values by specifying `*_converted_*` values for cash amounts. More details are [available in the DECISIONLOG](https://github.com/fivetran/dbt_quickbooks/blob/main/DECISIONLOG.md#multicurrency-vs-single-currency-configuration).

## Prerequisites
To use this dbt package, you must have the following:

- At least one Fivetran Quickbooks connection syncing data into your destination.
- A **BigQuery**, **Snowflake**, **Redshift**, **PostgreSQL**, or **Databricks** destination.

## How do I use the dbt package?
You can either add this dbt package in the Fivetran dashboard or import it into your dbt project:

- To add the package in the Fivetran dashboard, follow our [Quickstart guide](https://fivetran.com/docs/transformations/data-models/quickstart-management).
- To add the package to your dbt project, follow the setup instructions in the dbt package's [README file](https://github.com/fivetran/dbt_quickbooks/blob/main/README.md#how-do-i-use-the-dbt-package) to use this package.

<!--section-end-->

### Install the package
Include the following QuickBooks package version in your `packages.yml` file.
> TIP: Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.

```yaml
packages:
  - package: fivetran/quickbooks
    version: [">=1.3.0", "<1.4.0"] # we recommend using ranges to capture non-breaking changes automatically
```

> All required sources and staging models are now bundled into this transformation package. Do not include `fivetran/quickbooks_source` in your `packages.yml` since this package has been deprecated.

### Define database and schema variables
By default, this package runs using your destination and the `quickbooks` schema of your [target database](https://docs.getdbt.com/docs/running-a-dbt-project/using-the-command-line-interface/configure-your-profile). If this is not where your QuickBooks data is (for example, if your QuickBooks schema is named `quickbooks_fivetran`), add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    quickbooks_database: your_destination_name
    quickbooks_schema: your_schema_name 
```

### Enabling/Disabling Models
Your QuickBooks connection might not sync every table that this package expects. This package takes into consideration that not every QuickBooks account utilizes the same transactional tables.

By default, most variables' values are assumed to be `true` (with exception of `using_credit_card_payment_txn` and `using_purchase_order`). In other to enable or disable the relevant functionality in the package, you will need to add the relevant variables:

```yml
vars:
  using_address: false # disable if you don't have addresses in QuickBooks
  using_bill: false # disable if you don't have bills or bill payments in QuickBooks
  using_credit_memo: false # disable if you don't have credit memos in QuickBooks
  using_department: false # disable if you don't have departments in QuickBooks
  using_deposit: false # disable if you don't have deposits in QuickBooks
  using_estimate: false # disable if you don't have estimates in QuickBooks
  using_invoice: false # disable if you don't have invoices in QuickBooks
  using_invoice_bundle: false # disable if you don't have invoice bundles in QuickBooks
  using_journal_entry: false # disable if you don't have journal entries in QuickBooks
  using_payment: false # disable if you don't have payments in QuickBooks
  using_refund_receipt: false # disable if you don't have refund receipts in QuickBooks
  using_transfer: false # disable if you don't have transfers in QuickBooks
  using_vendor_credit: false # disable if you don't have vendor credits in QuickBooks
  using_sales_receipt: false # disable if you don't have sales receipts in QuickBooks
  using_credit_card_payment_txn: true # enable if you want to include credit card payment transactions in your staging models
  using_purchase_order: true #enable if you want to include purchase orders in your staging 

  ## Below variables are used to enable/disable sales tax components. All sales tax components are false by default.
  using_invoice_tax_line: true #enable if you have invoice tax lines in QuickBooks
  using_journal_entry_tax_line: true # enable if you have journal entry tax lines in QuickBooks
  using_purchase_tax_line: true # enable if you have purchase tax lines in QuickBooks
  using_refund_receipt_tax_line: true # enable if you have refund receipt tax lines in QuickBooks
  using_sales_receipt_tax_line: true # enable if you have sales receipt tax lines in QuickBooks
  using_tax_agency: true #enable if you have tax agencies in QuickBooks
  using_tax_rate: true #enable if you have tax rates in QuickBooks
```

### (Optional) Additional Configurations

#### Unioning Multiple Quickbooks Connections
If you have multiple Quickbooks connections in Fivetran and would like to use this package on all of them simultaneously, we have provided functionality to do so. The package will union all of the data together and pass the unioned table into the transformations. You will be able to see which source it came from in the `source_relation` column of each model. To use this functionality, you will need to set either the `quickbooks_union_schemas` or `quickbooks_union_databases` variables:

```yml
# dbt_project.yml

...
config-version: 2

vars:
    quickbooks_union_schemas: ['quickbooks_usa','quickbooks_canada'] # use this if the data is in different schemas/datasets of the same database/project
    quickbooks_union_databases: ['quickbooks_usa','quickbooks_canada'] # use this if the data is in different databases/projects but uses the same schema name
``` 

#### Configuring Account Type Names
Within a few of the double entry models in this package a mapping takes place to assign certain transaction type's debits/credits to the appropriate offset account (ie. Accounts Payable, Accounts Receivable, Undeposited Funds, and SalesOfProductIncome) reference. While our current filtered logic within our intermediate models account for the default values, it's possible your use case relies on different account types to reference.

See [DECISIONLOG](https://github.com/fivetran/dbt_quickbooks/blob/main/DECISIONLOG.md#designating-a-single-accounts-payableaccounts-receivable-account) for additional details on configuring account type names to avoid potential data fanout issues in the case of multiple accounts payable/receivable.

If you have a different value to reference for each type, you will need to configure the `account_type` and `account_sub_type` variables that account for these variables in your `dbt_project.yml`.

```yml
vars: 
  quickbooks__accounts_payable_reference: accounts_payable_value # 'Accounts Payable' is the default filter set for the account_type reference.
  quickbooks__accounts_receivable_reference: account_receivable_value # 'Accounts Receivable' is the default filter set for the account_type reference.
  quickbooks__undeposited_funds_reference: account_undeposited_funds_value # 'UndepositedFunds' is the default filter set for the account_sub_type reference.
  quickbooks__sales_of_product_income_reference: account_sales_of_product_income_value # 'SalesOfProductIncome' is the default filter set for the account_sub_type reference.
```

We conduct similar mappings to Global Tax and Sales Tax Account values, except they are applied to the account `name` field. If you have a different value to reference for each type, you will need to configure the `name` variables in your `dbt_project.yml`. **IMPORTANT**: Please make sure the account name is unique for your reference. [See the DECISIONLOG for more details](https://github.com/fivetran/dbt_quickbooks/blob/main/DECISIONLOG.md#bringing-in-the-right-tax-accounts-for-tax-lines).

```yml
vars:
  quickbooks__global_tax_account_reference: global_tax_account_value # 'Global Tax Payable' is the default filter set for the account name reference.
  quickbooks__sales_tax_account_reference: sales_tax_account_value # 'Sales Tax Payable' is the default filter set for the account name reference.
```

#### Customize the Cash Flow Model
**IMPORTANT**: It is very likely you will need to reconfigure your `cash_flow_type` to make sure your cash flow statement matches your specific use case. Please examine the following instructions.

The current default numbering for ordinals and default cash flow types are set in [the `int_quickbooks__cash_flow_classifications`](https://github.com/fivetran/dbt_quickbooks/blob/main/models/intermediate/int_quickbooks__cash_flow_classifications.sql) model. It's based on best practices for cash flow statements leveraging the indirect method in accounting. You can see these ordinals being created in the `int_quickbooks__cash_flow_classifications` model, then implemented in the `quickbooks__cash_flow_statement` model. The `cash_flow_type` value is assigned off of `account_class`, `account_name` or `account_type`, and the cash flow ordinal is assigned off of `cash_flow_type`.

If you'd like to modify either of these configurations, take the following steps to configure the fields you'd like to modify:

1) Create a csv file within your root (not the dbt package) `seeds` folder, then configure your `cash_flow_statement_type_ordinal` variable in your `dbt_project.yml` to reference the seed file name.
- For example, if you created a seed file named `quickbooks_cash_flow_types_ordinals.csv`, then you would edit the `cash_flow_statement_type_ordinal` in your root `dbt_project.yml` as such.

  ```yml
  vars:
     cash_flow_statement_type_ordinal: "{{ ref('quickbooks_cash_flow_types_ordinals') }}"
  ```

2) Examine [the `cash_flow_statement_type_ordinal_example` file](https://github.com/fivetran/dbt_quickbooks/tree/main/example_ordinal_seeds/cash_flow_statement_type_ordinal_example.csv) to see what your sample seed file should look like. (NOTE: Make sure that your file name you place in your `seeds` folder is different from `cash_flow_statement_type_ordinal_example` to avoid errors.). You can use this file as an example and follow the steps in (1) to see what the cash flow type and ordering of the data looks like for your configuration, then modify as needed. 
3) When adding and making changes to the seed file, you will need to run the `dbt build` command to compile the updated seed data into the above financial reporting models.

These are our recommended best practices to follow with your seed file--you can see them in action in [the `cash_flow_statement_type_ordinal_example` files](https://github.com/fivetran/dbt_quickbooks/tree/main/example_ordinal_seeds/cash_flow_statement_type_ordinal_example.csv): 
- REQUIRED: Every row should have a non-null `ordinal` and `cash_flow_type` column value. 
- REQUIRED: In each row of the seed file, only populate **ONE** of the `account_class`, `account_type`, `account_sub_type`, and `account_number` columns to avoid duplicated ordinals and cash flow types and test failures. This should also make the logic cleaner in defining which account value takes precedence in the ordering hierarchy. 
- In `cash_flow_statement_type_ordinal_example`, we recommend creating ordinals for each `cash_flow_type` value available (the default types are `Cash or Cash Equivalents`, `Operating`, `Investing`, `Financing` as per best financial practices, but you can configure as you like in your seed file) to make sure each cash flow statement type can be easily ordered. Then you can create any additional customization as needed with the more specific account fields to order even further.   
- In `cash_flow_statement_type_ordinal_example`, the `report` field should always be `Cash Flow`.

### Customize the account ordering of your financial models. 
[The current default numbering for ordinals](https://github.com/fivetran/dbt_quickbooks/blob/main/models/quickbooks__general_ledger_by_period.sql#L44-L50) is based on best practices for balance sheets and profit-and-loss statements in accounting. You can see these ordinals in action in the `quickbooks__general_ledger_by_period`, `quickbooks__balance_sheet` and `quickbooks__profit_and_loss` models. The ordinals are assigned off of the `account_class` values.

If you'd like to modify this, take the following steps:

1) Import a csv with fields into root (not the dbt package) `seeds` folder, then configure the `financial_statement_ordinal` variable in your `dbt_project.yml` to reference the seed file name. 
- For example, if you created a seed file named `quickbooks_ordinals.csv`, then you would edit the `financial_statement_ordinal` in your root `dbt_project.yml` as such.

  ```yml
  vars:
       financial_statement_ordinal: "{{ ref('quickbooks_ordinals') }}"
  ```

2) Examine the [`financial_statement_ordinal_example` file](https://github.com/fivetran/dbt_quickbooks/blob/main/example_ordinal_seeds/financial_statement_ordinal_example.csv) to see what your sample seed file should look like. (NOTE: Make sure that your `seed` file name is different from `financial_statement_ordinal_example` to avoid errors.). You can use this file as an example and follow the steps in (1) to see what the ordering of the data looks like, then modify as needed.

3) When adding and making changes to the seed file, you will need to run the `dbt build` command to compile the updated seed data into the above financial reporting models.

These are our recommended best practices to follow with your seed file ([you can see them in action in the `financial_statement_ordinal_example` file](https://github.com/fivetran/dbt_quickbooks/blob/main/example_ordinal_seeds/financial_statement_ordinal_example.csv)):
- REQUIRED: In each row of the seed file, only populate **ONE** of the `account_class`, `account_type`, `account_sub_type`, and `account_number` columns  to avoid duplicated ordinals and test failures. This should also make the logic cleaner in defining which account value takes precedence in the ordering hierarchy.
- We recommend creating ordinals for each `account_class` value available (usually 'Asset', 'Liability', 'Equity' for the Profit and Loss sheet, and 'Revenue' and 'Expense' for the Balance Sheet) to make sure each financial reporting line has an ordinal assigned to it. Then you can create any additional customization as needed with the more specific account fields to order even further.
- Fill out the `report` field as either `Balance Sheet` if the particular row belongs in `quickbooks__balance_sheet`, or `Profit and Loss` for `quickbooks__profit_and_loss`.
- We recommend ordering the `ordinal` for each report separately in the seed, i.e. have ordinals for `quickbooks__balance_sheet` and `quickbooks__profit_and_loss` start at 1 each, to make your reporting more clean.

#### Changing the Build Schema
By default this package will build the QuickBooks staging models within a schema titled (<target_schema> + `_quickbooks_staging`), QuickBooks intermediate (particularly the double entry) models within a schema titled (<target_schema> + `_quickbooks_intermediate`), and QuickBooks final models within a schema titled (<target_schema> + `_quickbooks`) in your target database. If this is not where you would like your modeled QuickBooks data to be written to, add the following configuration to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
models:
    quickbooks:
      +schema: my_new_schema_name # Leave +schema: blank to use the default target_schema.
      staging:
        +schema: my_new_schema_name # Leave +schema: blank to use the default target_schema.
```

#### Change the source table references
If an individual source table has a different name than the package expects, add the table name as it appears in your destination to the respective variable:
> IMPORTANT: See this project's [`dbt_project.yml`](https://github.com/fivetran/dbt_quickbooks/blob/main/dbt_project.yml) variable declarations to see the expected names.

```yml
vars:
    quickbooks_<default_source_table_name>_identifier: your_table_name 
``` 

### (Optional) Orchestrate your models with Fivetran Transformations for dbt Core™

Fivetran offers the ability for you to orchestrate your dbt project through [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt#transformationsfordbtcore). Learn how to set up your project for orchestration through Fivetran in our [Transformations for dbt Core setup guides](https://fivetran.com/docs/transformations/dbt/setup-guide#transformationsfordbtcoresetupguide).

### (Optional) Validate your data
After running the models within this package, you may want to compare the baseline financial statement totals from the data provided against what you expect. You can make use of the [analysis functionality of dbt](https://docs.getdbt.com/docs/building-a-dbt-project/analyses/) and run pre-written SQL to test these values. The SQL files within the [analysis](https://github.com/fivetran/dbt_quickbooks/blob/master/analysis) folder contain SQL queries you may compile to generate balance sheet and income statement values. You can then tie these generated values to your expected ones and confirm the values provided in this package are accurate.

## Does this package have dependencies?
This dbt package is dependent on the following dbt packages. These dependencies are installed by default within this package. For more information on the following packages, refer to the [dbt hub](https://hub.getdbt.com/) site.
> IMPORTANT: If you have any of these dependent packages in your own `packages.yml` file, we highly recommend that you remove them from your root `packages.yml` to avoid package version conflicts.

```yml
packages:
    - package: fivetran/fivetran_utils
      version: [">=0.4.0", "<0.5.0"]

    - package: dbt-labs/dbt_utils
      version: [">=1.0.0", "<2.0.0"]
```

<!--section="quickbooks_maintenance"-->
## How is this package maintained and can I contribute?

### Package Maintenance
The Fivetran team maintaining this package only maintains the [latest version](https://hub.getdbt.com/fivetran/quickbooks/latest/) of the package. We highly recommend you stay consistent with the latest version of the package and refer to the [CHANGELOG](https://github.com/fivetran/dbt_quickbooks/blob/main/CHANGELOG.md) and release notes for more information on changes across versions.

### Contributions
A small team of analytics engineers at Fivetran develops these dbt packages. However, the packages are made better by community contributions.

We highly encourage and welcome contributions to this package. Learn how to contribute to a package in dbt's [Contributing to an external dbt package article](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657).

### Opinionated Modelling Decisions
This dbt package takes an opinionated stance on how to define the ordering and cash flow types in our model based on best financial practices. Customers do have the option to customize these orderings and cash flow types with a seed file. [Instructions are available in the Additional Configuration section](https://github.com/fivetran/dbt_quickbooks/#optional-additional-configurations). If you would like a deeper explanation of the logic used by default or for more insight into certain modeling practices within this dbt package, [you may reference the DECISIONLOG](https://github.com/fivetran/dbt_quickbooks/blob/main/DECISIONLOG.md).

<!--section-end-->

## Are there any resources available?
- If you have questions or want to reach out for help, see the [GitHub Issue](https://github.com/fivetran/dbt_quickbooks/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran or would like to request a new dbt package, fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).
