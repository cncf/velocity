#!/bin/bash
if [ -z "$PG_PASS" ]
then
  echo "$0: you need to specify PG_PASS=..."
  exit 1
fi
if [ -z "$1" ]
then
  echo "$0: you need to specify actor column, for example dup_author_login"
  exit 2
fi
PG_DB=cloudfoundry GHA2DB_LOCAL=1 runq sql/commits_by_actor.sql {{actor}} "${1}" {{exclude_bots}} "`cat sql/exclude_bots.sql`"
