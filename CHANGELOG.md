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
