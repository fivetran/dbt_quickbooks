# dbt_quickbooks v0.17.0
[PR #146](https://github.com/fivetran/dbt_quickbooks/pull/146) introduces the following updates:

## Breaking Changes
- Introduced the following fields in the `quickbooks__general_ledger` model to better analyze real-time transaction data::
  - `created_at`: The time a transaction was first created.
  - `updated_at`: The time a transaction was last updated.
  - Updated the `*_double_entry` models to add these fields for each transaction type.
- This is a breaking change as this adds new fields to the existing schema. 

# dbt_quickbooks v0.16.0
[PR #143](https://github.com/fivetran/dbt_quickbooks/pull/143) introduces the following updates:

## Upstream Source Package Updates
- Deleted records have been previously been brought into the `dbt_quickbooks` package. To ensure accuracy in reporting, the following updates were made in the [v0.11.0 release](https://github.com/fivetran/dbt_quickbooks_source/releases/tag/v0.11.0) of `dbt_quickbooks_source`:
- We introduced the `_fivetran_deleted` field to filter out deleted records from the following staging models:
  - `stg_quickbooks__account`
  - `stg_quickbooks__bundle`
  - `stg_quickbooks__customer`
  - `stg_quickbooks__department`
  - `stg_quickbooks__item`
  - `stg_quickbooks__vendor`
- Since filtering out deleted records that were previously being counted impact all output models, this is being treated as a breaking change.

## Documentation update
- Added the `_fivetran_deleted` field to the above corresponding seed files in integration tests.

## Under The Hood
- Updated the `consistency_*_amounts` tests to include the `converted_amount` comparisons. They were previously commented out due to introducing multicurrency support in a previous release that would have led to test failures, but can now be brought in to properly validate these changes.

# dbt_quickbooks v0.15.0
[PR #142](https://github.com/fivetran/dbt_quickbooks/pull/142) introduces the following updates:

## Bug Fixes
- Updates the `int_quickbooks__sales_receipt_double_entry` model to prioritize the `invoice_lines.sales_item_account_id` as the second viable option in the `account_id` coalesce statements. This field was previously prioritized last. However, recent observations have made it apparent that when prioritized last, invoice transactions could be attributed to the wrong accounts.
  - While not a traditional breaking change, we made this a minor upgrade to account for scenarios where the end model results will likely change due to invoices being attributed to the correct accounts.

# dbt_quickbooks v0.14.1
[PR #138](https://github.com/fivetran/dbt_quickbooks/pull/138) introduces the following updates:

## Bug Fixes
- Added `nullif` logic to account for "divide by zero" errors in `int_quickbooks__deposit_double_entry` and `int_quickbooks__deposit_transactions` for when `total_amount` values from the `deposit` source table 
are zero.

## Under the Hood
- Added integrity test `deposit_ledger_amounts_match` within integration tests to compare deposit amounts between `int_quickbooks__deposit_double_entry` and deposit `transaction_type` values in `quickbooks__general_ledger`.
- Modified seed files in `integration_tests` to reproduce issue and confirm fixes.

# dbt_quickbooks v0.14.0
New major feature alert! Multicurrency is here!

## 🚨 Breaking Changes 🚨
### Feature Updates: Multicurrency Support
- We have introduced multicurrency support to the following models by providing these new fields that convert transaction amounts by their exchange rates. ([PR #134](https://github.com/fivetran/dbt_quickbooks/pull/134))
- **IMPORTANT**: We do not yet have proper `converted_amount` values for credit card payments and transfers. Currently it is being brought in as the equivalent of `amount`, so you might see slight discrepancies if need these values converted as well. [Please open an issue with us](https://github.com/fivetran/dbt_quickbooks/issues/new/choose) to help work with us to support this feature. 
- We have kept the existing cash value fields that provides amounts and balances to ensure full coverage to customers regardless of their currency setup. ([PR #134](https://github.com/fivetran/dbt_quickbooks/pull/134))
- The new multicurrency fields that fulfill the same function as the respective existing fields is below:

<!--section="new_multicurrency_fields_map"-->

| **Model** | **New Multicurrency Fields** | **Respective Single Currency Fields** |
| ------------------------ | ------------------------------------------------------------------------------------------------------- | ------------------------------------------ |    
| [quickbooks__general_ledger](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__general_ledger) | `adjusted_converted_amount`,  `running_converted_balance` |  `adjusted_amount`, `running_balance` | 
|[quickbooks__general_ledger_by_period](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__general_ledger_by_period) | `period_net_converted_change`, `period_beginning_converted_balance`, `period_ending_converted_balance`  | `period_net_change`, `period_beginning_balance`, `period_ending_balance`  |
| [quickbooks__profit_and_loss](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__profit_and_loss) |  `converted_amount` | `amount`  |
| [quickbooks__balance_sheet](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__balance_sheet) | `converted_amount` | `amount` |
| [quickbooks__cash_flow_statement](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__cash_flow_statement) |  `cash_converted_ending_period`, `cash_converted_beginning_period`, `cash_converted_net_period` | `cash_ending_period`, `cash_beginning_period`, `cash_net_period` |
| [quickbooks__ap_ar_enhanced](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__ap_ar_enhanced) | `total_converted_amount`, `estimate_total_converted_amount`, `total_current_converted_payment` | `total_amount`, `estimate_total_amount`, `total_current_payment` |
| [quickbooks__expenses_sales_enhanced](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.quickbooks__expenses_sales_enhanced) | `total_converted_amount`, `converted_amount` |  `total_amount`, `amount` |
<!--section-end-->

- Introduced `*_converted_*` type fields in our intermediate models to convert amounts where exchange rates exist for those transactions. If there is no exchange rate, these `*_converted_*` fields will default back to the already existing fields created for single currency, and all downstream calculations should match the single currency amount, balance and cash values. ([PR #134](https://github.com/fivetran/dbt_quickbooks/pull/134))
- For double-entry models that applied a cross-join to either AP/AR accounts, we are now mapping those accounts based on the `currency_id` value in the `accounts` source table for those transactions. ([PR #134](https://github.com/fivetran/dbt_quickbooks/pull/134))
- In the `analysis` folder, added the `converted_balance` to the `quickbooks__balance_sheet` and `ending_converted_balance` to the `quickbooks__income_statement` models. ([PR #134](https://github.com/fivetran/dbt_quickbooks/pull/134))

## Bug Fixes
- Adjusted logic for discount sales receipt lines in `int_quickbooks__sales_receipt_double_entry` model to bring in these values properly as negative adjusted amounts in the `quickbooks__general_ledger`. 
([PR #130](https://github.com/fivetran/dbt_quickbooks/pull/130))  
- Applied filter in `int_quickbooks__invoice_double_entry` to filter out 'Accounts Receivable' accounts that are inactive. ([PR #134](https://github.com/fivetran/dbt_quickbooks/pull/134)) 

## Under the Hood
- Added consistency and integrity tests within integration tests for all end models. ([PR #130](https://github.com/fivetran/dbt_quickbooks/pull/130)) & ([PR 134](https://github.com/fivetran/dbt_quickbooks/pull/134))
- Appended `using_credit_card_payment_txn` check in  `get_enabled_unioned_models` macro to `false` to match consistency of how the variable is defined throughout our Quickbooks models by default.

## Documentation Update
- Updated README to [reflect the new multicurrency support](https://github.com/fivetran/dbt_quickbooks?tab=readme-ov-file#multicurrency-vs-single-currency-configuration). ([PR #134](https://github.com/fivetran/dbt_quickbooks/pull/134))
- Added yml documentation with the new multicurrency fields and descriptions. ([PR #134](https://github.com/fivetran/dbt_quickbooks/pull/134))

## Contributors
- [@mikerenderco](https://github.com/mikerenderco) ([PR #131](https://github.com/fivetran/dbt_quickbooks/pull/131))

# dbt_quickbooks v0.13.1
[PR #125](https://github.com/fivetran/dbt_quickbooks/pull/125) includes the following updates:

## Bug Fix
- The `period_first_day` and `period_last_day` fields were mistakenly left out in the [quickbooks__profit_and_loss](https://github.com/fivetran/dbt_quickbooks/blob/main/models/quickbooks__profit_and_loss.sql) model although they were intended to be introduced as new fields [in the v0.13.0 release](https://github.com/fivetran/dbt_quickbooks/releases/tag/v0.13.0). We have added these fields into the model.

# dbt_quickbooks v0.13.0
[PR #124](https://github.com/fivetran/dbt_quickbooks/pull/124) includes the following updates:

## 🚨 Breaking Changes 🚨:
- Updates the [int_quickbooks__invoice_join](https://github.com/fivetran/dbt_quickbooks/blob/main/models/intermediate/int_quickbooks__invoice_join.sql) and downstream [quickbooks__ap_ar_enhanced](https://github.com/fivetran/dbt_quickbooks/blob/main/models/quickbooks__ap_ar_enhanced.sql) models to include and require the `using_payments` config. Previously, these models would fail if the `payment` or the `payment_line` source tables did not exist.
- Corrects the misspelled `customer_vendor_webiste` field to `customer_vendor_website` in `quickbooks__ap_ar_enhanced`.

## Bug Fixes
- Updates the logic for the `amount` field in [int_quickbooks__invoice_double_entry](https://github.com/fivetran/dbt_quickbooks/blob/main/models/double_entry_transactions/int_quickbooks__invoice_double_entry.sql) to use `invoice.total_amount` only on the condition when a bundle is associated with the invoice and `invoice.total_amount` is 0, otherwise `invoice_lines.amount` is used. 
   - This avoids double counting when aggregating invoice_line items and accounts for the edge cases where a bundle_id is involved.

## Feature Updates
- Updates the [quickbooks__profit_and_loss](https://github.com/fivetran/dbt_quickbooks/blob/main/models/quickbooks__profit_and_loss.sql) and [quickbooks__balance_sheet](https://github.com/fivetran/dbt_quickbooks/blob/main/models/quickbooks__balance_sheet.sql) models to include both `period_first_day` and `period_last_day` in addition to `calendar_date`. This allows users to have greater flexibility in choosing which date to aggregate records upon.
  - Please note `calendar_date` is slated to be deprecated, and the fields `period_first_day` and `period_last_day` are both offered as replacements, depending on how your company performs their financial reporting.

# dbt_quickbooks v0.12.4
[PR #123](https://github.com/fivetran/dbt_quickbooks/pull/123) includes the following updates:

## Bug Fixes
- Added `source_relation` to joins within the following models as it was previously missed:
   - `int_quickbooks__invoice_join`
   - `int_quickbooks__bill_join`
   - `int_quickbooks__refund_receipt_double_entry`
   - `int_quickbooks__sales_receipt_double_entry`
   - `quickbooks__balance_sheet` analysis model.

## Contributors
- [@MatteyRitch](https://github.com/MatteyRitch) ([PR #120](https://github.com/fivetran/dbt_quickbooks/pull/120))

# dbt_quickbooks v0.12.3
[PR #119](https://github.com/fivetran/dbt_quickbooks/pull/119) includes the following updates:

## Bug Fixes
- Included a default start and end date in the `int_quickbooks__general_ledger_date_spine` logic when generating the date spine. These default start and end dates will ensure the model still succeeds when no transactions are yet available.
  - The default start date will be one month in the past
  - The default end date will be the current date

## Under the Hood
- Updated the maintainer PR template to resemble the most 
up to date format.
- Removed the check docs GitHub Action as it is no longer necessary.

# dbt_quickbooks v0.12.2
[PR #114](https://github.com/fivetran/dbt_quickbooks/pull/114) includes the following updates:

## Bug Fixes
- Updated model `int_quickbooks__invoice_double_entry` to account for the `sales_item_account_id` field from the `invoice_lines` source when determining the `account_id` associated with an invoice. 

# dbt_quickbooks v0.12.1
[PR #109](https://github.com/fivetran/dbt_quickbooks/pull/109) includes the following updates:

## Bug Fixes
- Adjusted the joins within the below intermediate double entry models to be `left join` as opposed to an `inner join`. This update was necessary as there was the possibility of the respective account cte joins to return no records. If this was the case, the logic could erroneously remove transactions from the record.
  - [int_quickbooks__bill_payment_double_entry](https://github.com/fivetran/dbt_quickbooks/blob/main/models/double_entry_transactions/int_quickbooks__bill_payment_double_entry.sql)
  - [int_quickbooks__credit_memo_double_entry](https://github.com/fivetran/dbt_quickbooks/blob/main/models/double_entry_transactions/int_quickbooks__credit_memo_double_entry.sql)
  - [int_quickbooks__deposit_double_entry](https://github.com/fivetran/dbt_quickbooks/blob/main/models/double_entry_transactions/int_quickbooks__deposit_double_entry.sql)
  - [int_quickbooks__invoice_double_entry](https://github.com/fivetran/dbt_quickbooks/blob/main/models/double_entry_transactions/int_quickbooks__invoice_double_entry.sql)
  - [int_quickbooks__payment_double_entry](https://github.com/fivetran/dbt_quickbooks/blob/main/models/double_entry_transactions/int_quickbooks__payment_double_entry.sql)

# dbt_quickbooks v0.12.0
[PR #103](https://github.com/fivetran/dbt_quickbooks/pull/103/files) includes the following updates:
## 🚘 Under the Hood
- Update seeds and configs in the integration tests folder to match what was updated upstream in the ([source package PR #51](https://github.com/fivetran/dbt_quickbooks_source/pull/51)) to correct timestamp fields that should be date fields (`due_date`, `transaction_date`). Previously, some fields were getting interpreted as timestamps while some were interpreted as dates, leading to errors on downstream joins. In the upstream staging models, `due_date` and `transaction_date` are now explicitly cast as `date` types.

This will be a breaking change to those whose source tables still use the old timestamp formats, so please update your package version accordingly.

# dbt_quickbooks v0.11.1
This PR includes the following updates:

## 🐛 Bug Fixes 🩹
- Updated intermediate double entry models that have `account_type` and `account_sub_type` filters with configurable variables, since the type names used in the filter can be adjusted internally by QuickBooks customers. ([PR #98](https://github.com/fivetran/dbt_quickbooks/pull/98))
- Includes `items.asset_account_id` as the second field of the coalesce for the `payed_to_account_id` field within the `int_quickbooks__bill_payment_double_entry` model to ensure all account_id types are taken into consideration when mapping the transaction to the proper account. ([PR #100](https://github.com/fivetran/dbt_quickbooks/pull/100))

## 🎉 Feature Updates 🎉
- The intermediate models where these variables were introduced in the models below:

| **Updated model** | **New variables to filter on** |
| ----------| -------------------- |
| [int_quickbooks__bill_payment_double_entry](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.int_quickbooks__bill_payment_double_entry) | `quickbooks__accounts_payable_reference` |
| [int_quickbooks__credit_memo_double_entry](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.int_quickbooks__credit_memo_double_entry) | `quickbooks__accounts_receivable_reference` |
| [int_quickbooks__deposit_double_entry](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.int_quickbooks__deposit_double_entry) | `quickbooks__undeposited_funds_reference` |
| [int_quickbooks__invoice_double_entry](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.int_quickbooks__invoice_double_entry) | `quickbooks__sales_of_product_income_reference`, `quickbooks__accounts_receivable_reference` |
| [int_quickbooks__payment_double_entry](https://fivetran.github.io/dbt_quickbooks/#!/model/model.quickbooks.int_quickbooks__payment_double_entry) | `quickbooks__accounts_receivable_reference` |
 
## 🗒️ Documentation
- [Updated README with additional steps for configuration](https://github.com/fivetran/dbt_quickbooks/blob/main/README.md#optional-step-5-additional-configurations). This is an optional step since most customers will rely on the default account type/subtype values available.
  
## Contributors
- [@mikerenderco](https://github.com/mikerenderco) ([PR #100](https://github.com/fivetran/dbt_quickbooks/pull/100))

# dbt_quickbooks v0.11.0
## 🚨 Breaking Changes 🚨
[PR #95](https://github.com/fivetran/dbt_quickbooks/pull/95) includes the following updates:
## 🪲 Bug Fixes
- Included `source_relation` in all joins and window functions for models outputting `source_relation`. This is to prevent duplicate records in end models when using the unioning functionality. These updates were in the intermediate models, which flowed to downstream end models:
  - `quickbooks__general_ledger`
  - `quickbooks__expenses_sales_enhanced`
- In end model `quickbooks__general_ledger`, added `source_relation` as part of the generated surrogate key `unique_id` to prevent duplicate `unique_id`s when using the unioning functionality.

## 🎉 Features
- Added description for column `source_relation` to the documentation.

## 🚘 Under the Hood
- Updated test from a combination of columns to uniqueness of `unique_id` in `quickbooks__general_ledger`. 
- Updated partitioning in certain models to include `source_relation`. 
- Updated analysis `quickbooks__balance_sheet` with updated join strategy. 

# dbt_quickbooks v0.10.0
## 🎉 Feature Update 🎉
- Databricks compatibility! ([#92](https://github.com/fivetran/dbt_quickbooks/pull/92))

# dbt_quickbooks v0.9.1
[PR #93](https://github.com/fivetran/dbt_quickbooks/pull/93) includes the following updates:
## Bug Fixes
- Adjusted the purchase amount totals within the `int_quickbooks__purchase_transactions` model to factor in credits when calculating purchase amounts. 

# dbt_quickbooks v0.9.0
## Bug Fixes
- Added logic to the `int_quickbooks__invoice_double_entry` model to account for invoice discounts as they should be treated as contra revenue accounts that behavior differently from normal sale item detail invoice line items. ([#85](https://github.com/fivetran/dbt_quickbooks/pull/85))
- Updated the `cash_beginning_period` and `cash_net_period` values to coalesce to 0 in the `quickbooks__cash_flow_statement` in order to ensure every row has a value, especially the first row in the sequence since it will always be null. ([#88](https://github.com/fivetran/dbt_quickbooks/issues/88))

## Additional Features
- Added `department_id` to the `quickbooks__general_ledger` and the upstream tables required for that change. ([#63](https://github.com/fivetran/dbt_quickbooks/pull/63))
  - Please note that this field was not added to the downstream `quickbooks__general_ledger_by_period`, `quickbooks__balance_sheet`, `quickbooks__profit_and_loss`, or `quickbooks__cash_flow_statement` models as this would require the grain of these models to be adjusted for the `department_id`. This would likely cause more confusion in the initial output. As such, the field was omitted in the aggregate models to ensure consistency of these models. If you wish this to be included, please open a [Feature Request](https://github.com/fivetran/dbt_quickbooks/issues/new?assignees=&labels=enhancement&template=feature-request.yml&title=%5BFeature%5D+%3Ctitle%3E) to let us know!

## Documentation
- Included documentation [within the DECISIONLOG](https://github.com/fivetran/dbt_quickbooks/blob/main/DECISIONLOG.md) centered around the behavior of how invoice discounts are handled within the `int_quickbooks__invoice_double_entry` model. ([#85](https://github.com/fivetran/dbt_quickbooks/pull/85))

## Under the Hood
- Leveraged the new `detail_type` field to ensure better accuracy when identifying invoice lines that should be accounted for in the general ledger calculations. ([#85](https://github.com/fivetran/dbt_quickbooks/pull/85))
- Incorporated the new `fivetran_utils.drop_schemas_automation` macro into the end of each Buildkite integration test job. ([#87](https://github.com/fivetran/dbt_quickbooks/pull/87))
- Updated the pull request [templates](/.github). ([#87](https://github.com/fivetran/dbt_quickbooks/pull/87))

## Complimentary Release Notes
- See the source package [CHANGELOG](https://github.com/fivetran/dbt_quickbooks_source/blob/main/CHANGELOG.md#dbt_quickbooks_source-v080) for updates made to the staging layer in `dbt_quickbooks_source v0.8.0`.

## Contributors
- [@MarcelloMolinaro](https://github.com/MarcelloMolinaro) ([#63](https://github.com/fivetran/dbt_quickbooks/pull/63))
- [@SellJamHere](https://github.com/SellJamHere) ([#60](https://github.com/fivetran/dbt_quickbooks/pull/60))
- [@caffeinebounce](https://github.com/caffeinebounce) ([#88](https://github.com/fivetran/dbt_quickbooks/issues/88))

# dbt_quickbooks v0.8.1

## 🐛 Bug Fixes 🔨
- Adding partitions by `class_id` in appropriate models to ensure correct account amount aggregations in `quickbooks__general_ledger`, `quickbooks__general_ledger_by_period`, `quickbooks__balance_sheet`, and `quickbooks__profit_and_loss` models. ([#77](https://github.com/fivetran/dbt_quickbooks/pull/77))
- Modifying join in `int_quickbooks__general_ledger_balances` to account for null `class_id` values and bring in the correct non-zero balances. ([#77](https://github.com/fivetran/dbt_quickbooks/pull/77)) 


# dbt_quickbooks v0.8.0
## 🚨 Breaking Changes 🚨
- Replacing `account_name` with `account_id` as input for the `generate_surrogate_key` function to fix `unique_id` uniqueness issues in the `quickbooks__general_ledger` model.  A full refresh is recommended for accurate and consistent surrogate keys. ([#73](https://github.com/fivetran/dbt_quickbooks/pull/73))

# dbt_quickbooks v0.7.0
## 🚨 Breaking Changes 🚨
- Added `transaction_source` to `generate_surrogate_key` function to fix `unique_id` uniqueness issues in the `quickbooks__general_ledger` model.  A full refresh is recommended for accurate and consistent surrogate keys, for more information please refer to dbt-utils [release notes](https://github.com/dbt-labs/dbt-utils/releases/tag/1.0.0) regarding `generate_surrogate_key`. ([#62](https://github.com/fivetran/dbt_quickbooks/pull/62))

## Additional Features
- Created the `quickbooks__cash_flow_statement` model so customers can more easily produce their own cash flow statements. Default categorizations are created in `int_quickbooks__cash_flow_classifications`, where each account line is assigned a `cash_flow_type`, with main types being `Cash or Cash Equivalents`, `Operating`, `Investing`, and `Financing`. The `ordinal` value is also created based on the `cash_flow_type` for ordering purposes. All values created are based on cash flow best practices. ([#69](https://github.com/fivetran/dbt_quickbooks/pull/69))
- For the `quickbooks__cash_flow_statement`, customers can create and configure their own `cash_flow_type` and `ordinal` for ordering purposes. [See the README](https://github.com/fivetran/dbt_quickbooks/blob/main/README.md#customize-the-cash-flow-model) for details and [use the seed `cash_flow_statement_type_ordinal_example` file](https://github.com/fivetran/dbt_quickbooks/tree/main/example_ordinal_seeds/cash_flow_statement_type_ordinal_example.csv) for guidance). ([#69](https://github.com/fivetran/dbt_quickbooks/pull/69))
- Added `account_ordinal` value to `quickbooks__general_ledger_by_period`, `quickbooks__balance_sheet` and `quickbooks__profit_and_loss` to allow customers to order their financial reports based on the account field values. The ordinals can be further configured by the customer. [See the README](https://github.com/fivetran/dbt_quickbooks/blob/main/README.md#customize-the-account-ordering-of-your-financial-models) for details [and use the seed `financial_statement_ordinal_example` file](https://github.com/fivetran/dbt_quickbooks/blob/main/example_ordinal_seeds/seeds/financial_statement_ordinal_example.csv) for guidance). ([#65](https://github.com/fivetran/dbt_quickbooks/pull/65)) ([#66](https://github.com/fivetran/dbt_quickbooks/pull/66))
- Added `class_id` to `quickbooks__general_ledger`, `quickbooks_general_ledger_by_period`, and `quickbooks__balance_sheet`; add in class values for all intermediate models necessary to pass into final models. ([#58](https://github.com/fivetran/dbt_quickbooks/pull/58)).
- Added `source_relation` field to all Quickbooks models to allow customers, if they have multiple Quickbooks connectors, to union them inside the package. ([#62](https://github.com/fivetran/dbt_quickbooks/pull/62)).
- Added tests to all final models, particularly to test uniqueness across a combination of columns, including `source_relation`. ([#62](https://github.com/fivetran/dbt_quickbooks/pull/62))
- Modified `int_quickbooks__retained_earnings` intermediate model to accurately reflect `account_name` field, from "Net Income / Retained Earnings Adjustment" to "Net Income Adjustment". ([#66](https://github.com/fivetran/dbt_quickbooks/pull/66))
- Updated README to follow latest package standards. ([#71](https://github.com/fivetran/dbt_quickbooks/pull/71))
- Added `quickbooks_[source_table_name]_identifier` variables so it's easier to refer to source tables with different names. ([#71](https://github.com/fivetran/dbt_quickbooks/pull/71))

# dbt_quickbooks v0.6.0
## 🚨 Breaking Changes 🚨
[PR #51](https://github.com/fivetran/dbt_quickbooks/pull/51) includes the following breaking changes:
- Dispatch update for dbt-utils to dbt-core cross-db macros migration. Specifically `{{ dbt_utils.<macro> }}` have been updated to `{{ dbt.<macro> }}` for the below macros:
    - `any_value`
    - `bool_or`
    - `cast_bool_to_text`
    - `concat`
    - `date_trunc`
    - `dateadd`
    - `datediff`
    - `escape_single_quotes`
    - `except`
    - `hash`
    - `intersect`
    - `last_day`
    - `length`
    - `listagg`
    - `position`
    - `replace`
    - `right`
    - `safe_cast`
    - `split_part`
    - `string_literal`
    - `type_bigint`
    - `type_float`
    - `type_int`
    - `type_numeric`
    - `type_string`
    - `type_timestamp`
    - `array_append`
    - `array_concat`
    - `array_construct`
- For `current_timestamp` and `current_timestamp_in_utc` macros, the dispatch AND the macro names have been updated to the below, respectively:
    - `dbt.current_timestamp_backcompat`
    - `dbt.current_timestamp_in_utc_backcompat`
- Dependencies on `fivetran/fivetran_utils` have been upgraded, previously `[">=0.3.0", "<0.4.0"]` now `[">=0.4.0", "<0.5.0"]`.

# dbt_quickbooks v0.5.4
## Features
- Addition of the `credit_card_payment_txn` (enabled/disabled using the `using_credit_card_payment_txn` variable) source as well as the accompanying staging and intermediate models. This source includes all credit card payment transactions and will be used in downstream General Ledger generation to ensure accurate reporting of all transaction types. ([#61](https://github.com/fivetran/dbt_quickbooks/pull/61))
  >**Note**: the `credit_card_payment_txn` source and models are disabled by default. In order to enable them, you will want to set the `using_credit_card_payment_txn` variable to `true` in your dbt_project.yml.


## Contributors
- [@mikerenderco](https://github.com/mikerenderco) ([#50](https://github.com/fivetran/dbt_quickbooks/pull/50), [#47](https://github.com/fivetran/dbt_quickbooks/issues/47))
- [@mel-restori](https://github.com/mel-restori) ([#54](https://github.com/fivetran/dbt_quickbooks/pull/54), [#47](https://github.com/fivetran/dbt_quickbooks/issues/47))

# dbt_quickbooks v0.5.3
## Bug Fixes
- The `int_quickbooks__bill_payment_double_entry`, `int_quickbooks__credit_memo_double_entry`, `int_quickbooks__deposit_double_entry`, and `int_quickbooks__payment_double_entry` models perform a cross join on the `stg_quickbooks__accounts` model for the respective debit/credit account. However, if this cross join includes more than one record, it will result in duplicates. An additional filter to remove sub accounts has been added to ensure the output of the models do not have duplicates. ([#49](https://github.com/fivetran/dbt_quickbooks/pull/49))

## Under the Hood
- A GitHub workflow has been added to ensure the dbt docs are regenerated before each merge to the `main` release branch. ([#49](https://github.com/fivetran/dbt_quickbooks/pull/49))

# dbt_quickbooks v0.5.2
## Bug Fixes
- Within the `v0.5.1` release, the `transaction_id` field was erroneously removed from the `quickbooks__general_ledger` model. This field has since been added back. ([#46](https://github.com/fivetran/dbt_quickbooks/pull/46))

## Under the Hood
- Updated the `dbt-utils.surrogate_key()` macro to take the argument as a single list rather than a series of strings. This is to be in line with the proper use of the macro and ensure it is not impacted when the series of string argument is deprecated. ([#46](https://github.com/fivetran/dbt_quickbooks/pull/46))
# dbt_quickbooks v0.5.1
## Bug Fixes 🐛🪛
- Created indices for `double_entry_transactions` models. Used row_number functions for `payment`, `bill_payment` and `transfer` models. ([#41](https://github.com/fivetran/dbt_quickbooks/pull/41))
- Removed transaction index on final `quickbooks__general_ledger` model, replaced by the newer indices in the sub-ledgers. ([#41](https://github.com/fivetran/dbt_quickbooks/pull/41))
- Adjusted the `bundle_income_accounts` cte within the `int_quickbooks__invoice_double_entry` models to coalesce the parent and sub account id. This correctly removes any duplicate records caused from this cte in a downstream join. ([#42](https://github.com/fivetran/dbt_quickbooks/pull/42))
# dbt_quickbooks v0.5.0
## 🚨 Breaking Changes 🚨
- It was discovered that IDs from the source tables can sometimes be strings. The previous build of the package interpreted all IDs as integers. To ensure the package operates as intended, the package has been updated to cast all IDs to the string datatype. If you were leveraging the end models in downstream analysis, this change could break your join conditions. Be sure to be aware of any join conditions you may have downstream before upgrading your QuickBooks package. (#36)[https://github.com/fivetran/dbt_quickbooks/pull/36]
# dbt_quickbooks v0.4.0
🎉 dbt v1.0.0 Compatibility 🎉
## 🚨 Breaking Changes 🚨
- Adjusts the `require-dbt-version` to now be within the range [">=1.0.0", "<2.0.0"]. Additionally, the package has been updated for dbt v1.0.0 compatibility. If you are using a dbt version <1.0.0, you will need to upgrade in order to leverage the latest version of the package.
  - For help upgrading your package, I recommend reviewing this GitHub repo's Release Notes on what changes have been implemented since your last upgrade.
  - For help upgrading your dbt project to dbt v1.0.0, I recommend reviewing dbt-labs [upgrading to 1.0.0 docs](https://docs.getdbt.com/docs/guides/migration-guide/upgrading-to-1-0-0) for more details on what changes must be made.
- Upgrades the package dependency to refer to the latest `dbt_quickbooks_source`. Additionally, the latest `dbt_quickbooks_source` package has a dependency on the latest `dbt_fivetran_utils`. Further, the latest `dbt_fivetran_utils` package also has a dependency on `dbt_utils` [">=0.8.0", "<0.9.0"].
  - Please note, if you are installing a version of `dbt_utils` in your `packages.yml` that is not in the range above then you will encounter a package dependency error.

# dbt_quickbooks v0.1.0 -> v0.3.0
Refer to the relevant release notes on the Github repository for specific details for the previous releases. Thank you!
