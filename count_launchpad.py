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
args = parser.parse_args()
# print(args)
# print ((args.date_from, args.date_to))


lp = Launchpad(args.distribution, package=args.package, items_per_page=75, sleep_time=300, tag=None, archive=None)
# print(lp)

n = 0
for issue in lp.fetch(category=args.category, from_date=args.date_from):
    # print(issue.keys())
    # print(issue['data'].keys())
    dt = dateutil.parser.parse(issue['data']['date_created'])
    if dt > args.date_to:
        # print("skip {0}".format(dt))
        break
    n += 1
print((args.distribution, n))
