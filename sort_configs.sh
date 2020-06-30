#!/bin/bash
sed -i '1d' all_affs.csv
cat all_affs.csv | sort | uniq > out
echo '"email","name","company","date_to","source"' > all_affs.csv
cat out >> all_affs.csv
