### WebKit case

- Change the sh merger line to `ruby merger.rb data/unlimited.csv data/webkit_201606_201705.csv`
- WebKit has no usable data on GitHub, so running BigQuery is not needed, we no longer need those lines for WebKit (we will just update `data/webkit_201606_201705.csv` file), remove them from current shell `shells/unlimited_20160601-20170601.sh`:
```
echo "Updating WebKit project using gitdm and other"
ruby update_projects.rb projects/unlimited_both.csv data/data_webkit_gitdm_and_others.csv -1
```
- Now we need to generate the values for `data/webkit_201606_201705.csv` file:
- Issues:
Go to: https://webkit.org/reporting-bugs/
Search all bugs in webkit, order by modified desc - will be truncated to 10,000.
https://bugs.webkit.org/buglist.cgi?bug_status=UNCONFIRMED&bug_status=NEW&bug_status=ASSIGNED&bug_status=REOPENED&bug_status=RESOLVED&bug_status=VERIFIED&bug_status=CLOSED&limit=0&order=changeddate%20DESC%2Cbug_status%2Cpriority%2Cassigned_to%2Cbug_id&product=WebKit&query_format=advanced&resolution=---&resolution=FIXED&resolution=INVALID&resolution=WONTFIX&resolution=LATER&resolution=REMIND&resolution=DUPLICATE&resolution=WORKSFORME&resolution=MOVED&resolution=CONFIGURATION%20CHANGED <br/>Click the ID column. Open the first issue in a new tab and the last issue in the current tab. Bugs have a Reported date
2016-12-13 --> 2017-06-01 = 9988 issues:
ruby> Date.parse('2017-06-01') - Date.parse('2016-12-13') => (170/1), (9988.0 * 365.0/170.0) --> 21444 issues
See how many days makes 10k, and estimate for 365 days (1 year): gives 22k bugs/issues
- Commits, Authors:
`cd ~dev/ && git clone git://git.webkit.org/WebKit.git WebKit`. If already exists, do `git pull`
- Some git one liner stats:
All authors & commits:
`git log --all --pretty=format:"%aE" | sort | uniq | wc -l` --> 648
`git log --all --pretty=format:"%H" | sort | uniq | wc -l` --> 189693
And for our date period:
`git log --all --since "2017-11-01" --until "2018-11-01" --pretty=format:"%aE" | sort | uniq | wc -l` --> 125 authors
`git log --all --since "2017-11-01" --until "2018-11-01" --pretty=format:"%H" | sort | uniq | wc -l` --> 13348 commits
- Now use cncf/gitdm to analyse commits, authors: from `cncf/gitdm` directory run: `./repo_in_range.sh ~/dev/WebKit/ WebKit 2016-06-01 2017-06-01`
- See output: `vim other_repos/WebKit_2016-06-01_2017-06-01.txt`:
```
Processed 13337 csets from 125 developers
6 employers found
A total of 11838610 lines added, 3105609 removed (delta 8733001)
```
- So we have authors=125, commits=13348
- Now we need to estimate the remaining: prs, comments, activity:
- A good idea is to get it from ALL projects summaries (we have value for ALL keys summed-up in all projects from analysis.rb), this is automatically saved by `analysis.rb` to `reports/sumall.csv` file. The record from last `analysis.rb` run is: `{"activity"=>30714776, "comments"=>12766215, "prs"=>3311370, "commits"=>11687914, "issues"=>3104377}`
- Now average PRs/issues: sumall['prs'].to_f / sumall['issues'].to_f = 1.07 which gives PRs = 1.1 * 21444 (bugzilla above) = 23500
- Comments would be 2 * commits = 26000
- Activity = sum of all others (comments, commits, issues, prs)
- Create and open file `data/webkit_201606_201705.csv` from previous range file; edit and save

