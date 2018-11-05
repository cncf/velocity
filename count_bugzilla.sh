#!/usr/bin/env python3

import datetime
import argparse
import dateutil.parser
import pytz
from perceval.backends.core.bugzilla import Bugzilla

utc=pytz.UTC
def valid_datetime(s):
    try:
        return utc.localize(datetime.datetime.strptime(s, "%Y-%m-%d %H:%M:%S"))
    except ValueError:
        msg = "Not a valid date: '{0}'.".format(s)
        raise argparse.ArgumentTypeError(msg)

# Parse command line arguments
parser = argparse.ArgumentParser(description = "Count Bugzilla bugs in a given period")
parser.add_argument("-f", "--date-from", help = "Date from YYYY-MM-DD HH:MM:SS", required=True, type=valid_datetime)
parser.add_argument("-t", "--date-to", help = "Date to YYYY-MM-DD HH:MM:SS", required=True, type=valid_datetime)
parser.add_argument("-u", "--url", help = "Bugzilla URL", required=True, type=str)
parser.add_argument("-p", "--product", help = "Bugzilla Product", type=str)
parser.add_argument("-U", "--user", help = "Bugzilla user", type=str)
parser.add_argument("-P", "--password", help = "Bugzilla password", type=str)
parser.add_argument("-b", "--bugs", help = "Maximum number of bugs to fetch in a single call", default=200, type=int)
parser.add_argument("-c", "--category", help = "Bugzilla category (bug)", type=str, default="bug")
args = parser.parse_args()
# print(args)
# print ((args.date_from, args.date_to))

bugzilla = Bugzilla(args.url, user=args.user, password=args.password, max_bugs=200, max_bugs_csv=10000, tag=None, archive=None)
# print(bugzilla)

n = 0
for bug in bugzilla.fetch(category=args.category, from_date=args.date_from):
    # print(bug.keys())
    # print(bug['data'].keys())
    product = bug['data']['product'][0]['__text__']
    if args.product and args.product != product:
        continue
    dt = dateutil.parser.parse(bug['data']['creation_ts'][0]['__text__'])
    # print((product, dt))
    if dt > args.date_to:
        # print("skip {0} > {1}".format(dt, args.date_to))
        break
    n += 1
if args.product:
    print((args.product, n))
else:
    print(n)
