Try running this from the velocity project's root folder:
`ruby add_linux.rb data/data_lf_projects_20180401_20190401.csv data/data_linux.csv 2018-04-01 2019-04-01`.
- A message will be shown: `Data range not found in data/data_linux.csv: 2018-04-01 - 2019-04-01`. That means you need to add a new data range for Linux in file: `data/data_linux.csv`
- Go to: `https://lkml.org/lkml/2019` and sum-up monthly email counts for the time period of interest. This is also done via `/lkml_analysis.rb` script so you can skip fetching that number manually
- Add a row for the time period in `data/data_linux.csv`: `torvalds,torvalds/linux,2016-11-01,2017-11-01,0,0,0,0,263996,0` - You will see that now we only have the "emails" column. Other columns must be feteched from the linux kernel repo using the `cncf/gitdm` analysis:
	- Get `cncf/gitdm` with `git clone https://github.com/cncf/gitdm.git`
	- Get or update local linux kernel repo with `cd ~/dev/linux && git checkout master && git reset --hard && git pull`. An alternative to it (if you don't have the linux repo cloned) is: `cd ~/dev/`, `git clone https://github.com/torvalds/linux.git`.
	- Go to `cncf/gitdm/`, `cd ~/dev/cncf/gitdm/src` and run: `./linux_range.sh 2017-11-01 2018-11-01`
	- While in `cncf/gitdm/` directory, view: `vim linux_stats/range_2017-11-01_2018-11-01.txt`:
	```
	Processed 64482 csets from 3803 developers
	91 employers found
	A total of 3790914 lines added, 1522111 removed (delta 2268803)
	```
	- You have values for `changesets,additions,removals,authors` here, update `cncf/velocity/data/data_linux.csv` accordingly.
	
	- Final linux row data for the given time period is:
	```
	torvalds,torvalds/linux,2016-06-01,2017-06-01,64482,3790914,1522111,3803,254893,0
	```
- Put data for linux here `https://docs.google.com/spreadsheets/d/1CsdreHox8ev89WoP6LjcryroKDOH2gQipMC9oS95Zhc/edit?usp=sharing`.
- Run `PG_PASS=... ./linux_commits.sh 2018-04-01 2019-04-01` that will give a final values for number of pushes and commits. This is not needed but recommended. Otherwise put `0,0` for commits and pushes. Changesets are used to calculate output commits.
- Run `./lkml_analysis.rb 2018-04-01 2019-04-01` to get number of LKML emails (all) and new threads.
Run this from the velocity project's root folder again:
`ruby add_linux.rb data/data_lf_projects_20180401_20190401.csv data/data_linux.csv 2018-04-01 2019-04-01`

