# dbt_quickbooks_source v0.6.0
## Features
- Addition of the `credit_card_payment_txn` (enabled/disabled using the `using_credit_card_payment_txn` variable) source as well as the accompanying staging and intermediate models. This source includes all credit card payment transactions and will be used in downstream General Ledger generation to ensure accurate reporting of all transaction types. ([#50](https://github.com/fivetran/dbt_quickbooks/pull/50))
  >**Note**: the `credit_card_payment_txn` source and models are disabled by default. In order to enabled them, you will want to set the `using_credit_card_payment_txn` variable to `true` in your dbt_project.yml.

## Contributors
- [@mikerenderco](https://github.com/mikerenderco) ([#50](https://github.com/fivetran/dbt_quickbooks/pull/50))

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
