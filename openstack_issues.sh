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
for proj in nova neutron cinder openstack-manuals glance swift horizon keystone heat manila murano mistral openstack-api-site community
do
  # echo "project $proj"
  ./count_launchpad.py -f "$1" -t "$2" -d "$proj"  ${@:3:99}
done
