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

projs=(Flink Mesos Spark Kafka Camel CloudStack Beam Zeppelin Cassandra Hive HBase Hadoop Ignite NiFi Ambari Storm TS Lucene Solr CarbonData Geode Trafodion Thrift Kylin)
for proj in "${projs[@]}"
do
  # echo "project $proj"
  ./count_jira.py -f "$1" -t "$2" -u 'https://issues.apache.org/jira' -p "$proj"  ${@:3:99}
done
./count_jira.py -f "$1" -t "$2" -u 'https://issues.apache.org/jira'  ${@:3:99}
