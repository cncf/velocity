#!/bin/bash
cat sql/legacy_get_shas.sql | bq query --udf_resource=sql/get_shas.js
