#!/bin/bash
sed -i '1d' map/hints.csv
cat map/hints.csv | sort | uniq > out
echo 'repo,project' > map/hints.csv
cat out >> map/hints.csv

sed -i '1d' map/defmaps.csv
cat map/defmaps.csv | sort | uniq > out
echo 'name,project' > map/defmaps.csv
cat out >> map/defmaps.csv

sed -i '1d' map/urls.csv
cat map/urls.csv | sort | uniq > out
echo 'project,url' > map/urls.csv
cat out >> map/urls.csv
