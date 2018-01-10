[<- Back to the cncf/velocity README.md file](../README.md)

[Guide to non-github project processing](non_github_repositories.md)

### Processing unlimited BigQuery data

This means removing some filtering from BigQuery selects and letting Ruby tools perform the task instead.

To process "unlimited" data from BigQuery output (file `data/unlimited.csv`) , use `shells/unlimited.sh` or `shells/unlimited_both.sh`).
Unlimited means that BigQuery is not constraining repositories by having commits, comments, issues, PRs, authors > N (this N is 5-50 depending on which metric: authors for example is 5 while comments is 50).
Unlimited only requires that authors, comments, commits, prs, issues are all > 0.
And then only CSV `map/ranges_unlimited.csv` is used to further constrain data. This basically moves filtering out of BigQuery (so it can be called once) to the Ruby tool.
And `shells/unlimited_both.sh` uses `map/ranges_unlimited.csv` that is not setting ANY limit:
```
key,min,max,exceptions
activity,-1,-1,
comments,-1,-1,
prs,-1,-1,
commits,-1,-1,
issues,-1,-1,
authors,-1,-1,
```
It means that mapping must have an extremely long list of projects from repos/orgs to get valid non-obfuscated data.

You can skip a ton of organization's small repos (if they do not sum up to just few projects, while they are distinct), with:
`rauth[res[res.map { |i| i[0] }.index('Google')][0]].select { |i| i.split(',')[1].to_i < 14 }.map { |i| i.split(',')[0] }.join(',')`
The following is an example based on Google.
Say Top 100 projects have 100th project with 290 authors.
All tiny google repos (distinct small projects) will sum up and make Google overall 15th (for example).
The above command generates output list of google repos with 13 authors or less . You can put the results in map/skip.csv" and avoid false positives top 15 for Google overall (which would not be true)


### Special GitHub projects (like mirrors, backups etc.)

Follow these steps to add a new non-standard project (but from GitHub mirros, allowed are 0s on comments, commits, issues, prs, activity, authors):
- Copy `BigQuery/org_finder.sql` to clipboard and run this on BigQuery replacing condition for org (for example lower(org.login) like '%your%org%)
- Examine output org/repos combination (manually on GitHub) and decide about final condition for the final BigQuery run
- Copy `BigQuery/query_apache_projects.sql` into some `BigQuery/query_your_project.sql` then update conditions to those found in the previous step
- Run the query
- Save results to a table. Export this table to GStorage. Download this table as CSV from GStorage into `data/data_your_project_datefrom_date_to.csv`
- Add this to `shells/unlimited_both.csv`:
```
echo "Adding/Updating YourProject case"
ruby merger.rb data/unlimited.csv data/data_your_project_datefrom_date_to.csv
```
- Update `map/range*.csv` - add exception for YourProject (because it can have 0s now - this is output from BigQuery without numeric conditions)
- Run `shells/unlimited_both.sh` and examine Your Project (few iterations to add correct mapping in `./map/`: hints, defmaps, urls etc.)
- You can run manually: `ruby analysis.rb data/unlimited.csv projects/unlimited_both.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv`
- For example see YourProject rank: `res.map { |i| i[0] }.index('LibreOffice')` or `res[res.map { |i| i[0] }.index('LibreOffice')][2][:sum]`
- Some of the values will be missing (like for example PRs for mirror repos)
- Now it is time for a non standard path, please see `shells/unlimited_both.sh` for non standar data update that comes after final `ruby analysis.rb` call - this is usually different for each non-standard project


### Finding bots to be excluded in queries for project data

Two queries were created to be run in GoogleBigQuery. One for CloudFoundry, one for Chromium. Take a look at
`query_cloudfoundry_authors_from_to.sql` 
The result is in 
`data_cloudfoundry_authors_201611_201710.csv`
A bot can be spotted visually in the row where author (github login) is 'coveralls'
```
activity,comments,prs,commits,issues,author
1246,330,104,700,112,frodenas
1210,1210,0,0,0,coveralls
1164,88,58,979,39,genevievelesperance
```
The other authors can be validated to be human by going to address such as https://github.com/frodenas

Another way to identify bots would be by means af a query such as `query_chromium_authors_v2_from_to.sql` which lists names and counts of their commits. A results file such as `data_chromium_authors_v2_201611_2017_10.csv` brings data as follows:
```
activity,comments,prs,commits,issues,author_name
30583,17349,5997,25,7212,(null)
1549,0,0,1549,0,Matt Gaunt
857,0,0,857,0,Paul Irish
... ... ...
125,0,0,125,0,DevTools Bot
```

Bots should be excluded from the data queries and future bot hunting queries as to not duplicate efforts.

### Bubble Chart Generator

Usage:
Run `ruby chart_creator.rb projects/projects_lf_201701_201712.csv charts/lf_bubble_chart_2017.html 'Linux Foundation in 2017' 50`
to generate a bubble chart using google api.

parameters list:
first: required, location of file that is output of 'analysys.rb'
second: required, location of bubble chart file to be generated
third: optional, bubble chart title
fourth: optional, bubble count limit - integer

The generated file is a stand-alone html page that can be edited to suit needs such as change axis labels, adding a baseline, etc. Link to Google API used is embedded to the resulting html file.
