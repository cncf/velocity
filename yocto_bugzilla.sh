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
# possibly add -C 1 -D 30
# projs=(X Y Z)
projs=()
for proj in "${projs[@]}"
do
  #echo "project $proj"
  if [ ! -z "$REST" ]
  then
    ./count_bugzillarest.py -f "$1" -t "$2" -u 'https://bugzilla.yoctoproject.org' -p "$proj" ${@:3:99}
  else
    ./count_bugzilla.py -f "$1" -t "$2" -u 'https://bugzilla.yoctoproject.org' -p "$proj" ${@:3:99}
  fi
done
if [ ! -z "$REST" ]
then
  ./count_bugzillarest.py -f "$1" -t "$2" -u 'https://bugzilla.yoctoproject.org' ${@:3:99}
else
  ./count_bugzilla.py -f "$1" -t "$2" -u 'https://bugzilla.yoctoproject.org' ${@:3:99}
fi
