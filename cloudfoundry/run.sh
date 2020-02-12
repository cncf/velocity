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
if [ ! -z "$DROP" ]
then
  sudo -u postgres psql -c 'drop database if exists cloudfoundry' || exit 4
fi
./cloudfoundry/cloudfoundry.sh "${from}" "${to}" || exit 5
./cloudfoundry/cloudfoundry_analysis.sh "${from}" "${to}" || exit 6
echo "Analysis OK"
