<p align="center">
    <a alt="License"
        href="https://github.com/fivetran/dbt_quickbooks/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" /></a>
    <a alt="Fivetran-Release"
        href="https://fivetran.com/docs/getting-started/core-concepts#releasephases">
        <img src="https://img.shields.io/badge/Fivetran Release Phase-_Beta-orange.svg" /></a>
    <a alt="dbt-core">
        <img src="https://img.shields.io/badge/dbt_Core™_version->=1.0.0_,<2.0.0-orange.svg" /></a>
    <a alt="Maintained?">
        <img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg" /></a>
    <a alt="PRs">
        <img src="https://img.shields.io/badge/Contributions-welcome-blueviolet" /></a>
</p>

# QuickBooks Modeling dbt Package ([Docs](https://fivetran.github.io/dbt_quickbooks/))
# 📣 What does this dbt package do?
- Produces modeled tables that leverage QuickBooks data from [Fivetran's connector](https://fivetran.com/docs/applications/quickbooks) in the format described by [this ERD](https://docs.google.com/presentation/d/10lOpfJxsFWWP5OQKcYb-QX9YlQJvOcT4XyIDI_o7Vm0/edit) and build off the output of our [QuickBooks source package](https://github.com/fivetran/dbt_quickbooks_source).
- Enables you to better gain insights into your QuickBooks data that can be used for financial statement reporting and deeper analysis. The package achieves this by:
  - Creating a comprehensive general ledger that can be used to create financial statements with additional flexibility.
  - Providing historical general ledger month beginning balances, ending balances, and net change for each account.
  - Enhancing Accounts Payable and Accounts Receivables data by providing past and present aging of bills and invoices.
  - Pairing all expense and sales transactions in one table with accompanying data to provide enhanced analysis.
- Generates a comprehensive data dictionary of your source and modeled QuickBooks data through the [dbt docs site](https://fivetran.github.io/dbt_quickbooks/).

The following table provides a detailed list of all final models materialized within this package by default. 
> TIP: See more details about these models in the package's [dbt docs site](https://fivetran.github.io/dbt_quickbooks/#!/overview?g_v=1).

| **model**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [quickbooks__general_ledger](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__general_ledger) | Table containing a comprehensive list of all transactions with offsetting debit and credit entries to accounts. |
| [quickbooks__general_ledger_by_period](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__general_ledger_by_period) | Table containing the beginning balance, ending balance, and net change of the dollar amount for each month since the first transaction. This table can be used to generate a balance sheet and income statement for your business. |
| [quickbooks__profit_and_loss](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__profit_and_loss) | Table containing all revenue and expense account classes by calendar year and month enriched with account type, class, and parent information. |
| [quickbooks__balance_sheet](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__balance_sheet) | Table containing all asset, liability, and equity account classes by calendar year and month enriched with account type, class, and parent information. |
| [quickbooks__ap_ar_enhanced](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__ap_ar_enhanced) | Table providing the amount, amount paid, due date, and days overdue of all bills and invoices your company has received and paid along with customer, vendor, department, and address information for each invoice or bill. |
| [quickbooks__expenses_sales_enhanced](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__expenses_sales_enhanced) | Table providing enhanced customer, vendor, and account details for each expense and sale transaction. |

# 🎯 How do I use the dbt package?

## Step 1: Prerequisites
To use this dbt package, you must have the following:

- At least one Fivetran QuickBooks connector syncing data into your destination.
- A **BigQuery**, **Snowflake**, **Redshift**, or **PostgreSQL** destination.

## Step 2: Install the package
Include the following quickbooks package version in your `packages.yml` file:
> TIP: Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.
```yaml
packages:
  - package: fivetran/quickbooks
    version: [">=0.6.0", "<0.7.0"]

```
## Step 3: Define database and schema variables
By default, this package runs using your destination and the `quickbooks` schema. If this is not where your QuickBooks data is (for example, if your QuickBooks schema is named `quickbooks_fivetran`), add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    quickbooks_database: your_destination_name
    quickbooks_schema: your_schema_name 
```

## Step 4: Disable models for non-existent sources
This package takes into consideration that not every QuickBooks account utilizes the same transactional tables, and allows you to disable the corresponding functionality. By default, most variables' values are assumed to be `true` (with exception of purchase orders). Add variables within your root `dbt_project.yml` for only the tables you want to disable or enable respectively:

```yml
vars:
    using_address:        false         #disable if you don't have addresses in QuickBooks
    using_bill:           false         #disable if you don't have bills or bill payments in QuickBooks
    using_credit_memo:    false         #disable if you don't have credit memos in QuickBooks
    using_department:     false         #disable if you don't have departments in QuickBooks
    using_deposit:        false         #disable if you don't have deposits in QuickBooks
    using_estimate:       false         #disable if you don't have estimates in QuickBooks
    using_invoice:        false         #disable if you don't have invoices in QuickBooks
    using_invoice_bundle: false         #disable if you don't have invoice bundles in QuickBooks
    using_journal_entry:  false         #disable if you don't have journal entries in QuickBooks
    using_payment:        false         #disable if you don't have payments in QuickBooks
    using_refund_receipt: false         #disable if you don't have refund receipts in QuickBooks
    using_transfer:       false         #disable if you don't have transfers in QuickBooks
    using_vendor_credit:  false         #disable if you don't have vendor credits in QuickBooks
    using_sales_receipt:  false         #disable if you don't have sales receipts in QuickBooks
    using_purchase_order: true          #enable if you want to include purchase orders in your staging models
```

## (Optional) Step 5: Additional configurations
<details><summary>Expand for configurations</summary>
    
### Change the build schema
By default this package will build the QuickBooks staging models within a schema titled (<target_schema> + `_quickbooks_staging`) and QuickBooks final models within a schema titled (<target_schema> + `_quickbooks`) in your target database. If this is not where you would like your modeled QuickBooks data to be written to, add the following configuration to your `dbt_project.yml` file:

```yml
models:
    quickbooks:
      +schema: my_new_schema_name # leave blank for just the target_schema
    quickbooks_source:
      +schema: my_new_schema_name # leave blank for just the target_schema
```
    
### Change the source table references
If an individual source table has a different name than the package expects, add the table name as it appears in your destination to the respective variable:

> IMPORTANT: See this project's [`dbt_project.yml`](https://github.com/fivetran/dbt_quickbooks_source/blob/main/dbt_project.yml) variable declarations to see the expected names.

```yml
vars:
    quickbooks_<default_source_table_name>_identifier: your_table_name 
```
</details>

## (Optional) Step 7: Orchestrate your models with Fivetran Transformations for dbt Core™
<details><summary>Expand for details</summary>
<br>
    
Fivetran offers the ability for you to orchestrate your dbt project through [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt). Learn how to set up your project for orchestration through Fivetran in our [Transformations for dbt Core™ setup guides](https://fivetran.com/docs/transformations/dbt#setupguide).
</details>

# 🔍 Does this package have dependencies?
This dbt package is dependent on the following dbt packages. Please be aware that these dependencies are installed by default within this package. For more information on the following packages, refer to the [dbt hub](https://hub.getdbt.com/) site.
> IMPORTANT: If you have any of these dependent packages in your own `packages.yml` file, we highly recommend that you remove them from your root `packages.yml` to avoid package version conflicts.
    
```yml
packages:
    - package: fivetran/quickbooks_source
      version: [">=0.6.0", "<0.7.0"]

    - package: fivetran/fivetran_utils
      version: [">=0.3.0", "<0.4.0"]

    - package: dbt-labs/dbt_utils
      version: [">=0.8.0", "<0.9.0"]
```
# 🙌 How is this package maintained and can I contribute?
## Package Maintenance
The Fivetran team maintaining this package _only_ maintains the latest version of the package. We highly recommend you stay consistent with the [latest version](https://hub.getdbt.com/fivetran/quickbooks/latest/) of the package and refer to the [CHANGELOG](https://github.com/fivetran/dbt_quickbooks/blob/main/CHANGELOG.md) and release notes for more information on changes across versions.

## Contributions
A small team of analytics engineers at Fivetran develops these dbt packages. However, the packages are made better by community contributions! 

We highly encourage and welcome contributions to this package. Check out [this dbt Discourse article](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package!

## Analysis
After running the models within this package, you may want to compare the baseline financial statement totals from the data provided against what you expect. You can make use of the [analysis functionality of dbt](https://docs.getdbt.com/docs/building-a-dbt-project/analyses/) and run pre-written SQL to test these values. The SQL files within the [analysis](https://github.com/fivetran/dbt_quickbooks/blob/master/analysis) folder contain SQL queries you may compile to generate balance sheet and income statement values. You can then tie these generated values to your expected ones and confirm the values provided in this package are accurate.

# 🏪 Are there any resources available?
- If you have questions or want to reach out for help, please refer to the [GitHub Issue](https://github.com/fivetran/dbt_quickbooks/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran or would like to request a new dbt package, fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).
- Have questions or want to just say hi? Book a time during our office hours [on Calendly](https://calendly.com/fivetran-solutions-team/fivetran-solutions-team-office-hours) or email us at solutions@fivetran.com.
