#!/bin/bash

pnpm natspec-smells &> natspec-smells.report.txt

report_amount=$(grep -c '^$' natspec-smells.report.txt)

if [ $report_amount -eq 0 ]; then
  echo "✅ No natspec errors found."
else
  printf "❌ \x1b[31m$report_amount natspec errors found.\x1b[0m\n\tCheck \x1b[36m./natspec-smells.report.txt\x1b[0m for more information.\n"
  exit 1
fi