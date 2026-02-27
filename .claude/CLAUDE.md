# Overview
Check for the below commands and make the relevant changes as detailed in each of the below sections. Focus on the changes made compared to the main branch. 

A few notes when understanding the dbt package directory. Don't use the following directories within a dbt folder to obtain context, as these don't have relevant information:
- /dbt_packages/
- /logs/
- /target/
- package-lock.yml

## version bump
If the command run in claude is `version bump`, then make the following changes based on the changes made in the current branch.

### Have the versions already been updated?
Check the `dbt_project.yml` and `integration_tests/dbt_project.yml` files to see if the version has already been increased. The version should be different from the main branch version. If so, no need to make any changes. If one was updated, but not the other then be sure both versions match. If the change is a major (vX.0.0) or minor (v0.X.0) change then be sure to also update the `README.md` in the recommended version range section to the proper version range. The version range should always be the range in between the minor versions. So if the new version is v0.5.0 then the new range should be v0.5.0 to v0.6.0. 

If the versions have not been upgraded, proceed to the next section.

### Determine the type of change
We need to determine if the changes in the current branch are either a patch (v0.0.X), minor (v0.X.0), or a major (vX.0.0) change. For context, we typically only make patch and minor changes. A major change will only be used for significant updates. You will typically never make a major change. 

A patch change should only be used if there will be no material or breaking change impacts for the customer. However, a minor change should always be used if there are ever any data or schema changes.

### Required updates
Once the appropriate version is decided, the following files need to be updated:
- Update the version of the package in the:
    - `dbt_project.yml`
    - `integration_tests/dbt_project.yml`
    - (only if major vX.0.0 or minor v0.X.0 change) `README.md` in the recommended version range section

## CHANGELOG Entry
If the command run in claude is `changelog entry`, then make the following changes based on the changes made in the current branch. Use the writing rules of the Technical writing check section. 

### Understand the new version
If the versions in the `dbt_project.yml` or `integration_tests/dbt_project.yml` files have not been updated, follow the `version bump` steps then come back to these steps.

### CHANGELOG structure
The CHANGELOG entry structure should include sections only in the following subsections:
    - Schema/Data Change
        - Any change that will alter the schema (especially of the end models) by either a deletion, addition, or update to the schema or underlying data results.
    - Bug Fix
        - Fixing runtime or data integrity bugs that are not schema/data changes. This can be consolidated with the schema/data change.
    - Feature Update
        - Highlight any new features or components. This can be consolidated with the schema/data change.
    - Documentation
        - If only the README, DECISIONLOG, or any yml files are being updated then a documentation entry is needed.
    - Under the Hood
        - Any change that doesn't impact the end user. If there's an update in the integration_tests folder or any folder not impacting the end user than it will be an under the hood change.

There should be only a single a bullet for each relevant change and this change should be concisely documented for ease of understanding. The goal is for an end user to understand the exact change and the reason for this change as quickly as possible. When creating a schema/data change, create a table in the following structure for simpler and quicker understanding at a glance.
```md
## Schema/Data Change
**X total changes • X possible breaking changes**

| Data Model(s) | Change type | Old | New | Notes |
| ---------- | ----------- | -------- | -------- | ----- |
```

### Full refresh required?
If the change version is either a minor or major version bump and the changes are impacting incremental models or the change is adjusting the materialization, then you will need to add a note to the schema/data change section stating a full refresh is required. For example:
```md
## Schema/Data Change (--full-refresh required after upgrading)
```

## Spelling check
If the command run in claude is `spell check`, then make the following changes based on the changes made in the current branch.

### Review and make edits
Review all documentation and model files to look for spelling mistakes. Make any fixes.

## Bug Scan
If the command run in claude is `bug scan`, then make the following changes based on the changes made in the current branch.

### Review and check for bugs
Review the model files (putting a primary focus on the end models) and check for any potential bugs that could arise from end users running the models. These issues could either be runtime failures or data integrity issues.

## Schema check
If the command run in claude is `schema check`, then make the following changes based on the changes made in the current branch.

### New columns
Newly added columns must also be added to their corresponding get_*_columns macro and corresponding integration_tests/seeds CSVs. They must also be added to the dbt yaml documentation. New staging layer columns need to be added to both the stg_ and src_ yamls. Add them if they are missing.

### Deprecated columns
Deprecated columns must be marked as [DEPRECATED] in the dbt yaml documentation. Update if necessary.

### Removed columns
Removed columns must also be removed from their corresponding get_*_columns macro. They must also be removed from the dbt yaml documentation and corresponding integration_tests/seeds CSVs. Remove them if necessary.

## Validation tests
If the command run in claude is `validation test`, then make the following changes based on the changes made in the current branch.

### Consistency and Integrity tests
As part of our ongoing efforts to ensure data integrity, we aim to create reusable data integrity tests via consistency (check the results between dev and prod) and integrity (check the values from source to end model) tests. Review the updates made to the current branch and make a validation test to confirm the changes we are proposing will not introduce any unexpected errors. The goal is to test our code do not cause errors, rather than testing the data itself. Do not attempt to run these tests, only offer suggestions. These tests will be stored in the `integration_tests/tests/` folder.

## Health Scan
If the command run in claude is `health scan`, then make the following changes based on the changes made in the current branch.

### What to check
Follow the steps in the `spell check` and `bug scan` sections and make the changes.

## Technical writing check
If the command run in claude is `writing check`, then make the following changes based on the changes made in the current branch.

### Review and make edits
Review all documentation for clarity, flow, grammar, and the following Fivetran standards. Make any fixes.

Voice
Follow plain language/plain English practices. 
Use simple international English. 
Prefer simple words. 
Prefer short sentences.
Prefer the active voice. 
Use the present tense.
Use U.S. date format (month/day/year). 
Talk to our users, not about them 
You, not the user. 
RIGHT: You can select which tables to sync.
WRONG: The user can select which tables to sync. 
Use "Fivetran" sparingly 
Use Fivetran on the first mention in a section, then use we thereafter. Also, use the company name when it provides important context.
RIGHT: the Fivetran dashboard
WRONG: our dashboard
RIGHT: Fivetran captures deletes whenever we can detect them.
RIGHT: We pull data from your sources and send it to your destination using a set of fixed IP addresses (because the preceding header is Fivetran IP Addresses)

General language and formatting usage
Use present tense, not future tense.
RIGHT: Fivetran loads your tables.
WRONG: Fivetran will load your tables.
Use standard date notation format.
RIGHT: January 1, 2020
WRONG: January 1st, 2020

## Quickstart check
If the command run in claude is `quickstart`, then make the following changes based on the changes made in the current branch.

### Have any new end models been created?
End models are models that are neither staging models nor intermediate models. They are typically located directly in the models folder (not in staging/ or intermediate/ subdirectories). If any new end models have been created as a result of the changes made, check if a `.quickstart/quickstart.yml` file exists. If it does, add the new end models to the list of public models in that file. Add them if needed.

## Final finish check
If the command run in claude is `final check`, then run `version bump`, `schema check`, `changelog entry`, `quickstart`, `health scan`, `validation test`, and `writing check`.