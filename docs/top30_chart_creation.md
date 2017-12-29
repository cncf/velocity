[<- Back to the cncf/velocity README.md file](../README.md)

## Guide to the CNCF projects chart creation

`analysis.rb` can be used to create data for a Cloud Native Computing Foundation projects bubble chart such as this one
![sample chart](./top30_chart_example.png?raw=true "CNCF projects")

The chart itself can be generated in a [google sheet](https://docs.google.com/spreadsheets/d/14P8bML_jqutv1zzYy588rLSX-GjLy0Cc5aSCBY05CGE/)
or as a stand-alone [html page](../charts/top_30_201611_201710.html). Details on usage of google chart api are [here](https://developers.google.com/chart/interactive/docs/gallery/bubblechart).<br />The first option is a copy/paste of resulting data where the second presents more control to the look of the chart but data insertion is a little difficult.

#### Chart data

For every project find a github repo and add it to a query such as [this one](../BigQuery/query_lf_projects_201611_201710.sql) appropriately - either as an org or a single repo. If a project does not have a GitHub repo or only lists a mirror, skip it for now but later add manually.

Run the query on https://bigquery.cloud.google.com/queries/

Copy the results to a file.

Run `analysis.rb`

Make a copy of the [google doc](https://docs.google.com/spreadsheets/d/14P8bML_jqutv1zzYy588rLSX-GjLy0Cc5aSCBY05CGE/)

Put results of the analysis into a file and import the data in the 'Data' sheet in cell H1. <br />
File -> Import -> Upload -> in the Import location section, select the radio button called 'Replace data at selected cell', click Import data

Select the Chart tab, it will be updated automatically