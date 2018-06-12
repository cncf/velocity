#!/bin/sh
PG_DB=cloudfoundry runq ./cloudfoundry_commits.sql {{from}} 2017-06-01 {{to}} 2018-06-01
PG_DB=cloudfoundry runq ./cloudfoundry_prs_and_issues.sql {{from}} 2017-06-01 {{to}} 2018-06-01
