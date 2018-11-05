#!/usr/bin/env python3

import datetime
import argparse
import dateutil.parser
import pytz
from perceval.backends.core.jira import Jira

utc=pytz.UTC
def valid_datetime(s):
    try:
        return utc.localize(datetime.datetime.strptime(s, "%Y-%m-%d %H:%M:%S"))
    except ValueError:
        msg = "Not a valid date: '{0}'.".format(s)
        raise argparse.ArgumentTypeError(msg)

# Parse command line arguments
parser = argparse.ArgumentParser(description = "Count Jira issues in a given period")
parser.add_argument("-f", "--date-from", help = "Date from YYYY-MM-DD HH:MM:SS", required=True, type=valid_datetime)
parser.add_argument("-t", "--date-to", help = "Date to YYYY-MM-DD HH:MM:SS", required=True, type=valid_datetime)
parser.add_argument("-u", "--url", help = "Jira URL", required=True, type=str)
parser.add_argument("-p", "--project", help = "Jira project", type=str)
parser.add_argument("-U", "--user", help = "Jira user", type=str)
parser.add_argument("-P", "--password", help = "Jira password", type=str)
parser.add_argument("-i", "--issues", help = "Number of issues to fetch in a single call", default=100, type=int)
parser.add_argument("-c", "--category", help = "Jira category (issue)", type=str, default="issue")
args = parser.parse_args()
# print(args)
# print ((args.date_from, args.date_to))

jira = Jira(args.url, project=args.project, user=args.user, password=args.password, verify=False, cert=None, max_issues=args.issues, tag=None, archive=None)
# print(jira)

n = 0
for issue in jira.fetch(category=args.category, from_date=args.date_from):
    # print(issue.keys())
    # print(issue['data'].keys())
    # print(issue['data']['fields'].keys())
    # print(datetime.datetime.fromtimestamp(issue['data']['fields']['created']).strftime('%Y-%m-%d %H:%M:%S.%f'))
    # dt = dateutil.parser.parse(issue['data']['fields']['created'])
    dt = dateutil.parser.parse(issue['data']['fields']['updated'])
    # print(dt)
    if dt > args.date_to:
        # print("skip {0}".format(dt))
        break
    # print((issue['data']['id'], dt))
    n += 1
if args.project:
    print((args.project, n))
else:
    print(n)
