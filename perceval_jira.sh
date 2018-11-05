#!/bin/bash
if [ -z "${JIRA_USER}" ]
then
  echo -n "Jira user: "
  read JIRA_USER
fi
if [ -z "${JIRA_PWD}" ]
then
  echo -n "Jira Password: "
  read -s JIRA_PWD
fi
# --project 'ONOS'
# --project 'CORD'
# --project 'M-CORD'
# --project 'ONOS Ambassadors'
# perceval jira 'http://jira.onosproject.org' --category issue --project 'ONOS' -u "${JIRA_USER}" -p "${JIRA_PWD}" --verify False  > .jira.onosproject.org.jira.log
# with no --project specified it fetches all
perceval jira 'http://jira.onosproject.org' --category issue -u "${JIRA_USER}" -p "${JIRA_PWD}" --verify False  > .jira.onosproject.org.jira.log
