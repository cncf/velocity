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
parser.add_argument("-C", "--use-created-date", help = "Use created date instead of update date", type=lambda s: s.lower() in ['true', 't', 'yes', 'y', '1'])
parser.add_argument("-D", "--updated-diff", help = "If >=0 skip objects where created + diff > updated", type=int, default=-1)
args = parser.parse_args()
# print(args)
# print ((args.date_from, args.date_to))

bugzilla = Bugzilla(args.url, user=args.user, password=args.password, max_bugs=200, max_bugs_csv=10000, tag=None, archive=None)
# print(bugzilla)

oids = set()
for bug in bugzilla.fetch(category=args.category, from_date=args.date_from):
    # print(bug)
    # print(bug.keys())
    # print(bug['data'].keys())
    product = bug['data']['product'][0]['__text__']
    if args.product and args.product != product:
        continue
    # dtu = dateutil.parser.parse(bug['data']['delta_ts'][0]['__text__'])
    dtu = utc.localize(datetime.datetime.fromtimestamp(bugzilla.metadata_updated_on(bug['data'])))
    # print(dtu)
    if args.use_created_date:
        dtc = dateutil.parser.parse(bug['data']['creation_ts'][0]['__text__'])
        diff = (dtu - dtc) / datetime.timedelta(seconds=1)
        # print((product, dtc, dtu))
        if (args.updated_diff >= 0 and diff > args.updated_diff) or dtc < args.date_from or dtc > args.date_to:
            continue
    elif dtu > args.date_to:
        # print("skip {0} > {1}".format(dtu, args.date_to))
        break
    oids.add(bugzilla.metadata_id(bug['data']))
if args.product:
    print((args.product, len(oids)))
else:
    print(len(oids))
