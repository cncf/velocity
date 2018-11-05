#!/usr/bin/env python3

import datetime
import argparse
from perceval.backends.core.jira import Jira

def valid_date(s):
    try:
        return datetime.datetime.strptime(s, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        msg = "Not a valid date: '{0}'.".format(s)
        raise argparse.ArgumentTypeError(msg)

# Parse command line arguments
parser = argparse.ArgumentParser(description = "Count Jira issues in a given period")
parser.add_argument("-f", "--date-from", help = "Date from YYYY-MM-DD HH:MM:SS", required=True, type=valid_date)
parser.add_argument("-t", "--date-to", help = "Date to YYYY-MM-DD HH:MM:SS", required=True, type=valid_date)
parser.add_argument("-u", "--url", help = "Jira URL", required=True, type=str)
parser.add_argument("-p", "--project", help = "Jira project", type=str)
parser.add_argument("-U", "--user", help = "Jira user", type=str)
parser.add_argument("-P", "--password", help = "Jira password", type=str)
parser.add_argument("-i", "--issues", help = "Numbe rof issues to fetch in a single call", default=100, type=int)
parser.add_argument("-c", "--category", help = "Jira category", type=str, default="issue")
args = parser.parse_args()
print(args)

jira = Jira(args.url, project=args.project, user=args.user, password=args.password, verify=False, cert=None, max_issues=args.issues, tag=None, archive=None)
print(jira)

for issue in jira.fetch(category=args.category, from_date=args.date_from):
    print(issue)
    quit()
