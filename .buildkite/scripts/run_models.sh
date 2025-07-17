#!/bin/bash

set -euo pipefail

apt-get update
apt-get install libsasl2-dev

python3 -m venv venv
. venv/bin/activate
pip install --upgrade pip setuptools
pip install -r integration_tests/requirements.txt
mkdir -p ~/.dbt
cp integration_tests/ci/sample.profiles.yml ~/.dbt/profiles.yml

db=$1
echo `pwd`
cd integration_tests
dbt deps
dbt seed --target "$db" --full-refresh
dbt source freshness --target "$db" || echo "...Only verifying freshness runs..."
dbt run --target "$db" --full-refresh
dbt test --target "$db"
dbt run --vars '{using_credit_card_payment_txn: true, using_address: false, using_bill: false, using_credit_memo: false, using_department: false, using_deposit: false, using_estimate: false, using_invoice: false, using_invoice_bundle: false, using_invoice_tax_line: true, using_journal_entry: false, using_journal_entry_tax_line: true, using_payment: false, using_payment_tax_line: true, using_refund_receipt: false, using_refund_receipt_tax_line: true, using_sales_receipt: false, using_sales_receipt_tax_line: true, using_tax_agency: true, using_tax_code: true, using_tax_rate: true, using_transfer: false, using_vendor_credit: false}' --target "$db" --full-refresh
dbt test --target "$db"

dbt run-operation fivetran_utils.drop_schemas_automation --target "$db"
