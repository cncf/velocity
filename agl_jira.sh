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
./count_jira.py -f "$1" -t "$2" -u 'https://jira.automotivelinux.org'
