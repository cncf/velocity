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
parser.add_argument("-C", "--use-created-date", help = "Use created date instead of update date", type=lambda s: s.lower() in ['true', 't', 'yes', 'y', '1'])
parser.add_argument("-D", "--updated-diff", help = "If >=0 skip objects where created + diff > updated", type=int, default=-1)
args = parser.parse_args()
# print(args)

gitlab = GitLab(owner=args.owner, repository=args.repo, api_token=args.token, base_url=args.url, tag=None, archive=None, sleep_for_rate=args.sleep, min_rate_to_sleep=10, max_retries=5, sleep_time=1)
# print(gitlab)
# print ((args.date_from, args.date_to))

oids = set()
for obj in gitlab.fetch(category=args.category, from_date=args.date_from):
    # print(obj.keys())
    # print(obj['data'].keys())
    # dtu = dateutil.parser.parse(obj['data']['updated_at'])
    dtu = utc.localize(datetime.datetime.fromtimestamp(gitlab.metadata_updated_on(obj['data'])))
    # print(dtu)
    if args.use_created_date:
        dtc = dateutil.parser.parse(obj['data']['created_at'])
        diff = (dtu - dtc) / datetime.timedelta(seconds=1)
        # print((dtc, dtu))
        if (args.updated_diff >= 0 and diff > args.updated_diff) or dtc < args.date_from or dtc > args.date_to:
            # print("skip {0},{1}".format(dtc, dtu))
            continue
    elif dtu > args.date_to:
        # print("skip {0}".format(dtu))
        break
    oids.add(gitlab.metadata_id(obj['data']))
print((args.category, args.owner, args.repo, len(oids)))
