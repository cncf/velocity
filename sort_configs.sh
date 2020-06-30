#!/bin/bash
sed -i '1d' map/hints.csv
cat map/hints.csv | sort | uniq > out
echo 'repo,project' > map/hints.csv
cat out >> map/hints.csv
