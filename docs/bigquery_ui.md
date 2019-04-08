Verify [this query](BigQuery/query_20171101_20181101_unlimited.sql) for proper date range. If a project does not have a GitHub repo or only lists a mirror, skip it for now but later add manually.
Run the query on [BigQuery console](https://bigquery.cloud.google.com/queries/) or use `./BigQuery/query_20171101_20181101_unlimited.sh`.
Copy the results to a file like `data/unlimited_output_20171101_20181101.csv`. To do this, first Save as Table, then select the table in your google dataset. Next, export it as csv to gs://[BUCKET_NAME]/[FILENAME.CSV], where [BUCKET_NAME] is your Cloud Storage bucket name, and [FILENAME.CSV] is the name of your destination file. Then find the file in https://console.cloud.google.com/storage/browser/ and download it (file size is about 70MB). 

