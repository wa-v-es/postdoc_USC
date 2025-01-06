#Converts Julian day (i.e. from SAC) to YEAR, MONTH, DAY.
#Accounts for leap years. TEST: 2015 120 = 2016 04 30, 2016 120 = 2016 04 29
#Dan Frost
#17th July 2016

import datetime
import sys

year = int(sys.argv[1])
day = int(sys.argv[2])

day = day-1
date = datetime.datetime(year, 1, 1) + datetime.timedelta(day)
date_form = date.strftime('%Y %m %d')
print(date_form)

