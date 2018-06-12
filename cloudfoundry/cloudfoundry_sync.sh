#!/bin/bash
set -o pipefail
> errors.txt
> run.log
GHA2DB_LOCAL=1 PG_DB=cloudfoundry gha2db 2017-11-08 16 today now 'cloudfoundry,cloudfoundry-attic,cloudfoundry-community,cloudfoundry-incubator,cloudfoundry-samples' 2>>errors.txt | tee -a run.log || exit 2
echo "All done."
