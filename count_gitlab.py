#!/usr/bin/env python3

import datetime
import argparse
import dateutil.parser
import pytz
from perceval.backends.core.gitlab import GitLab

utc=pytz.UTC
def valid_datetime(s):
    try:
        return utc.localize(datetime.datetime.strptime(s, "%Y-%m-%d %H:%M:%S"))
    except ValueError:
        msg = "Not a valid date: '{0}'.".format(s)
        raise argparse.ArgumentTypeError(msg)

# Parse command line arguments
parser = argparse.ArgumentParser(description = "Count GitLab issues/merge requests in a given period")
parser.add_argument("-f", "--date-from", help = "Date from YYYY-MM-DD HH:MM:SS", required=True, type=valid_datetime)
parser.add_argument("-t", "--date-to", help = "Date to YYYY-MM-DD HH:MM:SS", required=True, type=valid_datetime)
parser.add_argument("-u", "--url", help = "GitLab base URL", type=str)
parser.add_argument("-o", "--owner", help = "GitLab owner/org", required=True, type=str)
parser.add_argument("-r", "--repo", help = "GitLab repo", required=True, type=str)
parser.add_argument("-s", "--sleep", help = "Sleep for rate", type=bool, default=False)
parser.add_argument("-T", "--token", help = "GitLab token", type=str)
parser.add_argument("-c", "--category", help = "Gitlab category (issue or merge_request)", type=str, default="issue")
args = parser.parse_args()
# print(args)

gitlab = GitLab(owner=args.owner, repository=args.repo, api_token=args.token, base_url=args.url, tag=None, archive=None, sleep_for_rate=args.sleep, min_rate_to_sleep=10, max_retries=5, sleep_time=1)
# print(gitlab)
# print ((args.date_from, args.date_to))

n = 0
for obj in gitlab.fetch(category=args.category, from_date=args.date_from):
    # print(obj.keys())
    # print(obj['data'].keys())
    dt = dateutil.parser.parse(obj['data']['created_at'])
    # print(dt)
    if dt >= args.date_from and dt < args.date_to:
        n += 1
print((args.category, n))
