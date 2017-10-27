import requests
import yaml
import json

full_repo_list = json.loads(requests.get(
    'https://review.openstack.org/projects/?d').text.split('\n', 1)[1])
governance = yaml.load(requests.get(
    'http://git.openstack.org/cgit/openstack/governance/plain/reference/projects.yaml',
    stream=True).raw)

retired_repos = [
    "openstack-infra/ansible-puppet",
    "openstack-infra/puppet-userstory_dashboard",
    "openstack-infra/userstory-dashboard",
    "openstack/defcore",
    "openstack/higgins",
    "openstack/nimble",
    "openstack/nomad",
    "openstack/openstack-ansible-ironic",
    "openstack/openstack-user-stories",
    "openstack/os-failures",
    "openstack/python-nimbleclient",
    "openstack/python-smaugclient",
    "openstack/rsc",
    "openstack/smaug",
    "openstack/smaug-dashboard",
]


repos = {}

for repo in retired_repos:
    repos[repo] = "OpenStack (retired)"

for repo in full_repo_list.keys():
    if (repo.startswith('stackforge')
            or '-attic' in repo
            or repo == 'All-Users'):
        continue
    else:
        repos[repo] = 'OpenStack Community'

for project_name, project in governance.items():
    for deliverable in project['deliverables'].values():
        for repo in deliverable['repos']:
            if project_name == 'Infrastructure':
                repos[repo] = 'OpenStack Infra'
            else:
                repos[repo] = 'OpenStack'

for repo_name in sorted(repos.keys()):
    print "{name},{group}".format(
        name=repo_name, group=repos[repo_name])
