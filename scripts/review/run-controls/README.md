# Run-control review fixtures

The `Review_Manual_Hidden_Invalid` Check Set is deliberately invalid: it combines
`RUN_ON_REQUEST` with `HIDE`, removing the only way to start a manual run. Deploy this fixture only
to an isolated review org to verify that the component surfaces the expected configuration error.
It is outside the package and integration-test source directories so release validation remains
clean.

The valid review cases live in `packages/record-health-check/integration-tests`:

- `Example_Account_Profile_Readiness`: long Run and Rerun labels.
- `Account_Advanced_Checks`: icon-only manual action.
- `Account_Data_Quality`: hidden automatic action.
- `Example_Account_Over_25_Checks`: 30-check cap with long Run and Rerun labels.
