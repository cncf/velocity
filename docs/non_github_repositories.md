[<- Back to the cncf/velocity README.md file](../README.md)

[Other useful notes](docs/other_notes.md)

### Adding non-GitHub projects
To manually add other projects (like Linux) use `add_linux.sh` or create similar tools for other projects. Data for this tool was generated manually using a custom `gitdm` tool (`github cncf/gitdm`) on `torvalds/linux` repo and via manually counting email addresses in different periods on LKML.
Example usage (assuming Linux additional data in `data/data_linux.csv)`, could be: 
`ruby add_linux.rb data/data_201603.csv data/data_linux.csv 2016-03-01 2016-04-01`

A larger scope (e.g. GitHub data) file can be injected with such custom script results data (from Gitlab or Linux or External) by the merger script:
`ruby merger.rb file_to_merge.csv file_to_get_data_from.csv`
See for example `./shells/top30_201605_201704.sh`
Every merge will compound data into the merger file.
