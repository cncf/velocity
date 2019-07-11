#!/bin/sh
if ( [ -z "$1" ] || [ -z "$2" ] )
then
  echo "$0: you need to provide date from and date to"
  exit 1
fi
GHA2DB_CSVOUT="data_openstack_$1_$2.csv" GHA2DB_LOCAL=1 PG_DB=contrib runq ./openstack_data.sql {{exclude_bots}} "`cat ~/dev/cncf/contributors/util_sql/exclude_bots.sql`" {{from}} $1 {{to}} $2
