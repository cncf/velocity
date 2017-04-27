# velocity
Track development velocity

`analysis.rb` is a tool that process input file (which is an aoutput from BigQuery) and generates final data for Bubble/Motion Google Sheet Chart.
It uses hint file with additional repo name -> project mapping.
Example use:
`analysis.rb input.csv output.csv hints.csv`
`input.csv` data from BigQuery, like this:
```
org,repo,activity,comments,prs,commits,issues,authors
kubernetes,kubernetes/kubernetes,11243,9878,720,70,575,40
ethereum,ethereum/go-ethereum,10701,570,109,43,9979,14
...
```
`output.csv` to be imported via Google Sheet (File -> Import) and then chart created from this data. It looks like this:
```
org,repo,activity,comments,prs,commits,issues,authors,project
dotnet,corefx+coreclr+roslyn+cli+docs+core-setup+corefxlab+roslyn-project-system+sdk+corert+eShopOnContainers+core+buildtools,20586,14964,1956,1906,1760,418,dotnet
kubernetes+kubernetes-incubator,kubernetes+kubernetes.github.io+test-infra+ingress+charts+service-catalog+helm+minikube+dashboard+bootkube+kargo+kube-aws+community+heapster,20249,15735,2013,1323,1178,423,Kubernetes
...
```
`hint.csv` CSV file with hints for repo --> project, it looks like this:
```
repo,project
Microsoft/TypeScript,Microsoft TypeScript
...
```

`hintgen.rb` is a tool that takes data already processed for various created charts and creates distinct projects hint file from it:
`hintgen.rb data.csv hints.csv`
Use multiple times putting different files as 1st parameter (`data.csv`) and generate final `hints.csv`.
