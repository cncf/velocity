#!/bin/sh
if [ -z "$PG_PASS" ]
then
  echo "$0: you need to specify PG_PASS=..."
  exit 1
fi
if [ -z "$1" ]
then
  echo "$0: you need to specify date from YYYY-MM-DD as a first arg"
  exit 2
fi
if [ -z "$2" ]
then
  echo "$0: you need to specify date to YYYY-MM-DD as a second arg"
  exit 3
fi
from="${1}"
to="${2}"
GHA2DB_LOCAL=1 PG_DB=cloudfoundry runq ./cloudfoundry/cloudfoundry_commits.sql {{from}} "${from}" {{to}} "${to}" {{exclude_bots}} "`cat sql/exclude_bots.sql`" || exit 4
GHA2DB_LOCAL=1 PG_DB=cloudfoundry runq ./cloudfoundry/cloudfoundry_prs.sql {{from}} "${from}" {{to}} "${to}" {{exclude_bots}} "`cat sql/exclude_bots.sql`" || exit 5
GHA2DB_LOCAL=1 PG_DB=cloudfoundry runq ./cloudfoundry/cloudfoundry_issues.sql {{from}} "${from}" {{to}} "${to}" {{exclude_bots}} "`cat sql/exclude_bots.sql`" || exit 5
