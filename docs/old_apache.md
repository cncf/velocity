- Now go to their jira: issues.apache.org/jira/browse, you may set conditions to find issues, like this:
```
project = "Kylin" AND created >= 2016-05-01 AND created <= 2017-05-01
```
Example URL: `https://issues.apache.org/jira/browse/KYLIN-2578?jql=project%20%3D%20%27Kylin%27%20and%20created%20%3E%3D%202016-05-01%20AND%20created%20%3C%3D%202017-05-01`
We need issue counts for all projects separately: Flink, Mesos, Spark, Kafka, Camel, CloudStack, Beam, Zeppelin, Cassandra, Hive, HBase, Hadoop, Ignite, NiFi, Ambari, Storm, Traffic Server, Lucene - Core, Solr, CarbonData, Geode, Trafodion, Thrift, Kylin.
