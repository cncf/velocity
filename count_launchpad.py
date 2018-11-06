#!/usr/bin/env python3

import datetime
import argparse
import dateutil.parser
import pytz
from perceval.backends.core.launchpad import Launchpad

utc=pytz.UTC
def valid_datetime(s):
    try:
        return utc.localize(datetime.datetime.strptime(s, "%Y-%m-%d %H:%M:%S"))
    except ValueError:
        msg = "Not a valid date: '{0}'.".format(s)
        raise argparse.ArgumentTypeError(msg)

# Parse command line arguments
parser = argparse.ArgumentParser(description = "Count launchpad issues in a given period")
parser.add_argument("-f", "--date-from", help = "Date from YYYY-MM-DD HH:MM:SS", required=True, type=valid_datetime)
parser.add_argument("-t", "--date-to", help = "Date to YYYY-MM-DD HH:MM:SS", required=True, type=valid_datetime)
parser.add_argument("-d", "--distribution", help = "Launchpad distribution", required=True, type=str)
parser.add_argument("-p", "--package", help = "Launchpad package", type=str)
parser.add_argument("-c", "--category", help = "Launchpad category (issue)", type=str, default="issue")
parser.add_argument("-C", "--use-created-date", help = "Use created date instead of update date", type=lambda s: s.lower() in ['true', 't', 'yes', 'y', '1'])
parser.add_argument("-D", "--updated-diff", help = "If >=0 skip objects where created + diff > updated", type=int, default=-1)
args = parser.parse_args()
# print(args)
# print ((args.date_from, args.date_to))


lp = Launchpad(args.distribution, package=args.package, items_per_page=75, sleep_time=300, tag=None, archive=None)
# print(lp)

oids = set()
for issue in lp.fetch(category=args.category, from_date=args.date_from):
    # print(issue)
    # print(issue.keys())
    # print(issue['data'].keys())
    # print(issue['data']['bug_data'].keys())
    # dtu = dateutil.parser.parse(issue['data']['bug_data']['date_last_updated'])
    dtu = utc.localize(datetime.datetime.fromtimestamp(lp.metadata_updated_on(issue['data'])))
    # print(dtu)
    if args.use_created_date:
        dtc = dateutil.parser.parse(issue['data']['date_created'])
        diff = (dtu - dtc) / datetime.timedelta(seconds=1)
        # print((dtc, dtu))
        if (args.updated_diff >= 0 and diff > args.updated_diff) or dtc < args.date_from or dtc > args.date_to:
            continue
    elif dtu > args.date_to:
        # print("skip {0}".format(dtu))
        break
    oids.add(lp.metadata_id(issue['data']))
print((args.distribution, args.package, len(oids)))
