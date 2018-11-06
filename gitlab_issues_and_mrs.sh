#!/bin/bash
if [ -z "$1" ]
then
  echo "$0: please provide date from YYYY-MM-DD HH:MI:SS"
  exit 1
fi
if [ -z "$2" ]
then
  echo "$0: please provide date to YYYY-MM-DD HH:MI:SS"
  exit 2
fi
TOKEN=`cat /etc/gitlab/token`
./count_gitlab.py -f "$1" -t "$2" -o gitlab-org -r gitlab-ce -T "${TOKEN}" -c issue  ${@:3:99}
./count_gitlab.py -f "$1" -t "$2" -o gitlab-org -r gitlab-ce -T "${TOKEN}" -c merge_request  ${@:3:99}
