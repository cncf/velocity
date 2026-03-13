# Get the data from Google BigQuery

Run the query: `` [DBG=1] ./run_bq_templated.sh linux_and_zephyr 20250101 20260101 ``.

It will generate a file: `data/data_linux_and_zephyr_projects_20250101_20260101.csv`.

Since October 7th 2025 GHA no longer have PushEvents commits data, so we need to reconstruct this using `git log` on cloned repos to get commits contributors count, do this via:

```
./tools/enrich_authors/enrich_authors -in data/data_linux_and_zephyr_projects_20250101_20260101.csv -out data/data_linux_and_zephyr_projects_20250101_20260101.enriched.csv -from 2025-01-01 -to 2026-01-01 -forks lf_forks.json -debug
cp data/data_linux_and_zephyr_projects_20250101_20260101.csv data/data_linux_and_zephyr_projects_20250101_20260101.raw.csv
cp data/data_linux_and_zephyr_projects_20250101_20260101.enriched.csv data/data_linux_and_zephyr_projects_20250101_20260101.csv
```

Run `` ./lkml_analysis.rb 2025-01-01 2026-01-01 `` from `cncf/velocity` to get number of LKML emails (all) and new threads. This takes hours to complete. Update `data/data_linux.csv` with this data.

Run this: `` OVERWRITE=1 SKIP_COMMITS=1 ruby add_linux.rb data/data_linux_and_zephyr_projects_20250101_20260101.csv data/data_linux.csv 2025-01-01 2026-01-01 `` to add LKML data to the main data file.

Run `analysis.rb` with:
```
export RUBYOPT='-EASCII-8BIT:ASCII-8BIT'
[SKIP_TOKENS=''] FORKS_FILE=lf_forks.json ruby analysis.rb data/data_linux_and_zephyr_projects_20250101_20260101.csv projects/projects_linux_and_zephyr_20250101_20260101.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges_sane.csv
```

Make a copy of the [google doc](https://docs.google.com/spreadsheets/d/1x4ptBeaIY85xo41kkD3iV8AicVY92fKG10zuOXTabXA/edit?usp=sharing).

Put results of the analysis into a file and import the data in the 'Data' sheet in cell A300.
File -> Import -> Upload -> in the Import location section, select the radio button called 'Replace data at selected cell', click Import data.
