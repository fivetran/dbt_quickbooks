# QuickBooks dbt Package ([Docs](https://fivetran.github.io/dbt_quickbooks/))

<p align="left">
    <a alt="License"
        href="https://github.com/fivetran/dbt_quickbooks/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" /></a>
    <a alt="dbt-core">
        <img src="https://img.shields.io/badge/dbt_Core™_version->=1.3.0_,<2.0.0-orange.svg" /></a>
    <a alt="Maintained?">
        <img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg" /></a>
    <a alt="PRs">
        <img src="https://img.shields.io/badge/Contributions-welcome-blueviolet" /></a>
    <a alt="Fivetran Quickstart Compatible"
        href="https://fivetran.com/docs/transformations/dbt/quickstart">
        <img src="https://img.shields.io/badge/Fivetran_Quickstart_Compatible%3F-yes-green.svg" /></a>
</p>

## Table of Contents
- [What does this dbt package do?](https://github.com/fivetran/dbt_quickbooks/#-what-does-this-dbt-package-do)
- [How do I use the dbt package?](https://github.com/fivetran/dbt_quickbooks_source/#-how-do-i-use-the-dbt-package)
    - [Required steps](https://github.com/fivetran/dbt_quickbooks/#step-1-prerequisites)
    - [Additional options](https://github.com/fivetran/dbt_quickbooks/#optional-step-5-additional-configurations)
  - [Does this package have dependencies?](https://github.com/fivetran/dbt_quickbooks/#-does-this-package-have-dependencies)
  - [How is this package maintained and can I contribute?](https://github.com/fivetran/dbt_quickbooks/#-how-is-this-package-maintained-and-can-i-contribute)
- [Package Maintenance](https://github.com/fivetran/dbt_quickbooks/#package-maintenance)
- [Contributions](https://github.com/fivetran/dbt_quickbooks/#contributions)
- [Are there any resources available?](https://github.com/fivetran/dbt_quickbooks/#-are-there-any-resources-available)

## What does this dbt package do?
- Produces modeled tables that leverage QuickBooks data from [Fivetran's connector](https://fivetran.com/docs/applications/quickbooks) in the format described by [this ERD](https://fivetran.com/docs/applications/quickbooks#schemainformation) and builds off the output of our [QuickBooks source package](https://github.com/fivetran/dbt_quickbooks_source).

- Enables users with insights into their QuickBooks data that can be used for financial statement reporting and deeper analysis. The package achieves this by:
  - Creating a comprehensive general ledger that can be used to create financial statements with additional flexibility.
  - Providing historical general ledger month beginning balances, ending balances, and net change for each account.
  - Enhancing Accounts Payable and Accounts Receivables data by providing past and present aging of bills and invoices.
  - Pairing all expense and sales transactions in one table with accompanying data to provide enhanced analysis.
  - Producing end financial statement models like balance sheet, profit and loss, and cash flow for optimized financial reporting.
- Generates a comprehensive data dictionary of your source and modeled QuickBooks data through the [dbt docs site](https://fivetran.github.io/dbt_quickbooks/).

<!--section="quickbooks_transformation_model"-->
The following table provides a detailed list of all tables materialized within this package by default. The primary outputs of this package are described below. Intermediate tables are used to create these outputs.

> TIP: See more details about these tables in the package's [dbt docs site](https://fivetran.github.io/dbt_quickbooks/#!/overview?g_v=1&g_e=seeds).

| **Table**                | **Description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [quickbooks__general_ledger](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__general_ledger) | Table containing a comprehensive list of all transactions with offsetting debit and credit entries to accounts. |
| [quickbooks__general_ledger_by_period](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__general_ledger_by_period) | Table containing the beginning balance, ending balance, and net change of the dollar amount for each month since the first transaction. This table can be used to generate a balance sheet and income statement for your business. |
| [quickbooks__profit_and_loss](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__profit_and_loss) | Table containing all revenue and expense account classes by calendar year and month enriched with account type, class, and parent information, as well as ordering configuration--[scroll below for details](https://github.com/fivetran/dbt_quickbooks/blob/main/README.md#customize-the-account-ordering-of-your-profit-loss-and-balance-sheet-models). |
| [quickbooks__balance_sheet](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__balance_sheet) | Table containing all asset, liability, and equity account classes by calendar year and month enriched with account type, class, and parent information, as well as ordering configuration--[scroll below for details](https://github.com/fivetran/dbt_quickbooks/blob/main/README.md#customize-the-account-ordering-of-your-profit-loss-and-balance-sheet-models). |
| [quickbooks__cash_flow_statement](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__cash_flow_statement) | Table containing all cash or cash equivalents, investing, operating, and financing cash flow types by calendar year and month enriched with account type, class, and parent information, as well as ordering configuration. **IMPORTANT**: It is very likely you will need to configure the cash flow types for your own unique use case. [Scroll below to get full instructions for how to configure your cash flow types](https://github.com/fivetran/dbt_quickbooks/blob/main/README.md#customize-the-cash-flow-types-and-account-ordering-of-your-cash-flow-statement). |
| [quickbooks__ap_ar_enhanced](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__ap_ar_enhanced) | Table providing the amount, amount paid, due date, and days overdue of all bills and invoices your company has received and paid along with customer, vendor, department, and address information for each invoice or bill. |
| [quickbooks__expenses_sales_enhanced](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__expenses_sales_enhanced) | Table providing enhanced customer, vendor, and account details for each expense and sale transaction. |

### Materialized Models
Each Quickstart transformation job run materializes 94 models if all components of this data model are enabled. This count includes all staging, intermediate, and final models materialized as `view`, `table`, or `incremental`.
<!--section-end-->

### Multicurrency Support

> [dbt_quickbooks](https://github.com/fivetran/dbt_quickbooks) and [dbt_quickbooks_source](https://github.com/fivetran/dbt_quickbooks_source) now supports multicurrency by bringing in values by specifying `*_converted_*` values for cash amounts. More details are [available in the DECISIONLOG](https://github.com/fivetran/dbt_quickbooks/blob/main/DECISIONLOG.md#multicurrency-vs-single-currency-configuration).

## How do I use the dbt package?
### Step 1: Prerequisites
To use this dbt package, you must have the following:

- At least one Fivetran QuickBooks connection syncing data into your destination.
- A **BigQuery**, **Snowflake**, **Redshift**, **PostgreSQL**, or **Databricks** destination.

### Step 2: Install the package
Include the following QuickBooks package version in your `packages.yml` file.
> TIP: Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.

```yaml
packages:
  - package: fivetran/quickbooks
    version: [">=0.21.0", "<0.22.0"] # we recommend using ranges to capture non-breaking changes automatically
```

Do NOT include the `quickbooks_source` package in this file. The transformation package itself has a dependency on it and will install the source package as well.

### Step 3: Define database and schema variables
By default, this package runs using your destination and the `quickbooks` schema of your [target database](https://docs.getdbt.com/docs/running-a-dbt-project/using-the-command-line-interface/configure-your-profile). If this is not where your QuickBooks data is (for example, if your QuickBooks schema is named `quickbooks_fivetran`), add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    quickbooks_database: your_destination_name
    quickbooks_schema: your_schema_name 
```

### Step 4: Enabling/Disabling Models
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
  using_purchase_order: true #enable if you want to include purchase orders in your staging models
```

### (Optional) Step 5: Additional Configurations

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

If you have a different value to reference for each type, you will need to configure the `account_type` and `account_sub_type` variables that account for these variables in your `dbt_project.yml`.

```yml
vars: 
  quickbooks__accounts_payable_reference: accounts_payable_value # 'Accounts Payable' is the default filter set for the account_type reference.
  quickbooks__accounts_receivable_reference: account_receivable_value # 'Accounts Receivable' is the default filter set for the account_type reference.
  quickbooks__undeposited_funds_reference: account_undeposited_funds_value # 'UndepositedFunds' is the default filter set for the account_subtype reference.
  quickbooks__sales_of_product_income_reference: account_sales_of_product_income_value # 'SalesOfProductIncome' is the default filter set for the account_subtype reference.
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
      +schema: my_new_schema_name # leave blank for just the target_schema

    quickbooks_source:
      +schema: my_new_schema_name # leave blank for just the target_schema
```

#### Change the source table references
If an individual source table has a different name than the package expects, add the table name as it appears in your destination to the respective variable:
> IMPORTANT: See this project's [`dbt_project.yml`](https://github.com/fivetran/dbt_quickbooks_source/blob/main/dbt_project.yml) variable declarations to see the expected names.

```yml
vars:
    quickbooks_<default_source_table_name>_identifier: your_table_name 
``` 

### (Optional) Step 6: Orchestrate your models with Fivetran Transformations for dbt Core™

Fivetran offers the ability for you to orchestrate your dbt project through [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt). Learn how to set up your project for orchestration through Fivetran in our [Transformations for dbt Core setup guides](https://fivetran.com/docs/transformations/dbt#setupguide).

### (Optional) Step 7: Validate your data
After running the models within this package, you may want to compare the baseline financial statement totals from the data provided against what you expect. You can make use of the [analysis functionality of dbt](https://docs.getdbt.com/docs/building-a-dbt-project/analyses/) and run pre-written SQL to test these values. The SQL files within the [analysis](https://github.com/fivetran/dbt_quickbooks/blob/master/analysis) folder contain SQL queries you may compile to generate balance sheet and income statement values. You can then tie these generated values to your expected ones and confirm the values provided in this package are accurate.

## Does this package have dependencies?
This dbt package is dependent on the following dbt packages. These dependencies are installed by default within this package. For more information on the following packages, refer to the [dbt hub](https://hub.getdbt.com/) site.
> IMPORTANT: If you have any of these dependent packages in your own `packages.yml` file, we highly recommend that you remove them from your root `packages.yml` to avoid package version conflicts.

```yml
packages:
    - package: fivetran/quickbooks_source
      version: [">=0.14.0", "<0.15.0"]

    - package: fivetran/fivetran_utils
      version: [">=0.4.0", "<0.5.0"]

    - package: dbt-labs/dbt_utils
      version: [">=1.0.0", "<2.0.0"]
```

## How is this package maintained and can I contribute?
### Package Maintenance
The Fivetran team maintaining this package _only_ maintains the latest version of the package. We highly recommend that you stay consistent with the [latest version](https://hub.getdbt.com/fivetran/quickbooks_source/latest/) of the package and refer to the [CHANGELOG](https://github.com/fivetran/dbt_quickbooks/blob/main/CHANGELOG.md) and release notes for more information on changes across versions.

### Contributions
A small team of analytics engineers at Fivetran develops these dbt packages. However, the packages are made better by community contributions.

We highly encourage and welcome contributions to this package. Check out [this dbt Discourse article](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) to learn how to contribute to a dbt package.

### Opinionated Modelling Decisions
This dbt package takes an opinionated stance on how to define the ordering and cash flow types in our model based on best financial practices. Customers do have the option to customize these orderings and cash flow types with a seed file. [Instructions are available in the Additional Configuration section](https://github.com/fivetran/dbt_quickbooks/#optional-step-5-additional-configurations). If you would like a deeper explanation of the logic used by default or for more insight into certain modeling practices within this dbt package, [you may reference the DECISIONLOG](https://github.com/fivetran/dbt_quickbooks/blob/main/DECISIONLOG.md).

## Are there any resources available?
- If you have questions or want to reach out for help, see the [GitHub Issue](https://github.com/fivetran/dbt_quickbooks/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran or would like to request a new dbt package, fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).