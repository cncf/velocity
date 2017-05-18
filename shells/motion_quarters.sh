#!/bin/sh
# summary data
echo "Summary data"
echo "Add linux summary"
ruby add_linux.rb data/data_201501-201704.csv data/data_linux.csv 2015-01-01 2017-05-01
echo "Merge CNCF summary"
ruby merger.rb data/data_201501-201704.csv data/data_cncf_projects_201501_201704.csv
echo "Analysis summary"
ruby analysis.rb data/data_201501-201704.csv projects/projects_201501-201704.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
# quarters linux
echo "Quarters data"
echo "Add linux quarters"
ruby add_linux.rb data/data_2015Q1.csv data/data_linux.csv 2015-01-01 2015-04-01
ruby add_linux.rb data/data_2015Q2.csv data/data_linux.csv 2015-04-01 2015-07-01
ruby add_linux.rb data/data_2015Q3.csv data/data_linux.csv 2015-07-01 2015-10-01
ruby add_linux.rb data/data_2015Q4.csv data/data_linux.csv 2015-10-01 2016-01-01
ruby add_linux.rb data/data_2016Q1.csv data/data_linux.csv 2016-01-01 2016-04-01
ruby add_linux.rb data/data_2016Q2.csv data/data_linux.csv 2016-04-01 2016-07-01
ruby add_linux.rb data/data_2016Q3.csv data/data_linux.csv 2016-07-01 2016-10-01
ruby add_linux.rb data/data_2016Q4.csv data/data_linux.csv 2016-10-01 2017-01-01
ruby add_linux.rb data/data_2017Q1.csv data/data_linux.csv 2017-01-01 2017-04-01
# quarters CNCF data merge
echo "Merge CNCF quarters"
ruby merger.rb data/data_2015Q1.csv data/data_cncf_2015Q1.csv
ruby merger.rb data/data_2015Q2.csv data/data_cncf_2015Q2.csv
ruby merger.rb data/data_2015Q3.csv data/data_cncf_2015Q3.csv
ruby merger.rb data/data_2015Q4.csv data/data_cncf_2015Q4.csv
ruby merger.rb data/data_2016Q1.csv data/data_cncf_2016Q1.csv
ruby merger.rb data/data_2016Q2.csv data/data_cncf_2016Q2.csv
ruby merger.rb data/data_2016Q3.csv data/data_cncf_2016Q3.csv
ruby merger.rb data/data_2016Q4.csv data/data_cncf_2016Q4.csv
ruby merger.rb data/data_2017Q1.csv data/data_cncf_2017Q1.csv
# quarters data
echo "Analysis quarters"
ruby analysis.rb data/data_2015Q1.csv projects/projects_2015Q1.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
ruby analysis.rb data/data_2015Q2.csv projects/projects_2015Q2.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
ruby analysis.rb data/data_2015Q3.csv projects/projects_2015Q3.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
ruby analysis.rb data/data_2015Q4.csv projects/projects_2015Q4.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
ruby analysis.rb data/data_2016Q1.csv projects/projects_2016Q1.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
ruby analysis.rb data/data_2016Q2.csv projects/projects_2016Q2.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
ruby analysis.rb data/data_2016Q3.csv projects/projects_2016Q3.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
ruby analysis.rb data/data_2016Q4.csv projects/projects_2016Q4.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
ruby analysis.rb data/data_2017Q1.csv projects/projects_2017Q1.csv map/hints.csv map/urls.csv map/defmaps.csv map/skip.csv map/ranges.csv
# final motion
echo "Final motion generation"
ruby generate_motion.rb projects/files_quarter.csv motion/motion_quarter.csv motion/motion_quarter_sums.csv projects/projects_201501-201704.csv
