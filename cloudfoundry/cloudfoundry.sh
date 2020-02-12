#!/bin/bash
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
set -o pipefail
> errors.txt
> run.log
PG_DB=cloudfoundry GHA2DB_MGETC=y structure 2>>errors.txt | tee -a run.log || exit 4
PG_DB=cloudfoundry gha2db "${from}" 0 "${to}" 23 'cloudfoundry,cloudfoundry-attic,cloudfoundry-community,cloudfoundry-incubator,cloudfoundry-samples' 2>>errors.txt | tee -a run.log || exit 5
PG_DB=cloudfoundry GHA2DB_MGETC=y GHA2DB_SKIPTABLE=1 GHA2DB_INDEX=1 structure 2>>errors.txt | tee -a run.log || exit 6
echo "All done."
