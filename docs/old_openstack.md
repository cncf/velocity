- Old approach (using BigQuery)
- Change line `ruby merger.rb data/unlimited.csv data/data_openstack_201605_201704.csv` to `ruby merger.rb data/unlimited.csv data/data_openstack_201606_201705.csv`
- To get `data/data_openstack_201606_201705.csv` file from BigQuery do:
- Copy `cp BigQuery/query_openstack_projects.sql BigQuery/query_openstack_projects_201606_201705.sql` and update date range condition in `BigQuery/query_openstack_projects_201606_201705.sql`
- Copy to clipboard `pbcopy < BigQuery/query_openstack_projects_201606_201705.sql` and run BigQuery, Save as Table, export to gstorage, and save the results as `data/data_openstack_201606_201705.csv`
- Run `ruby merger.rb data/unlimited.csv data/data_openstack_201606_201705.csv` for a test

