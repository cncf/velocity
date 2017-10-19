#!/bin/sh
WD=`pwd`
FN=$WD/agl.log
F=$WD/agl
> $FN
for var in "$@"
do
  echo "Processing $var"
  cd "$var" || exit 1
  git config merge.renameLimit 100000
  git config diff.renameLimit 100000
  git log --numstat -M --since "$DTFROM" --until "$DTTO" >> $FN
  git config --unset diff.renameLimit
  git config --unset merge.renameLimit
  ls -l $FN
  cd $WD
done
cat $FN | ~/dev/cncf/gitdm/cncfdm.py -r '^vendor/|/vendor/|^Godeps/' -R -n -b ~/dev/cncf/gitdm/ -t -z -d -D -U -u -f "$DTFROM" -e "$DTTO" -h $F.html -o $F.txt -x $F.csv > $F.out
