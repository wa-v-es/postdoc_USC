#!/usr/bin/env python
import glob
from obspy.core import read
from obspy.geodetics.base import gps2dist_azimuth
from obspy.signal import rotate
import sys
import pandas as pd
import os

#Filter Parameters
f1=0.001; f2=20.0                    # Filter corners (Hz) to plot only
corn=1                            # Number of filer corners
filtphase=True                    # Zerophase (True) or causal (False)

#Construct event list
ev_yr=[]
ev_mo=[]
ev_da=[]
ev_ho=[]
ev_mn=[]
ev_sc=[]
ev_ms=[]
ev_la=[]
ev_lo=[]
ev_dp=[]
ev_date=[]
#for infile_ev in ('../evlist_download1.txt', '../evlist_download2.txt', '../evlist_download3.txt', '../evlist_download4.txt'):
#for infile_ev in ('../all_events.txt'):
infile_ev='../all_events.txt' 
with open (infile_ev) as filein:
     for line_aa in filein.readlines():
         line_aa = line_aa.strip()
         line_bb = line_aa.split(' ')
         ev_yr.append(line_bb[0])
         ev_mo.append(line_bb[1]) #int() to remove leading zeros
         ev_da.append(line_bb[2])
         ev_ho.append(line_bb[3])
         ev_mn.append(line_bb[4])
         ev_sc.append(line_bb[5])
         ev_ms.append(line_bb[6])

#         ev_mo.append((line_bb[1]).lstrip('0')) #int() to remove leading zeros
#         ev_da.append((line_bb[2]).lstrip('0'))
#         ev_ho.append((line_bb[3]).lstrip('0'))
#         ev_mn.append((line_bb[4]).lstrip('0'))
#         ev_sc.append((line_bb[5]).lstrip('0'))
#         ev_ms.append((line_bb[6]).lstrip('0'))

         ev_la.append(line_bb[7])
         ev_lo.append(line_bb[8])
         ev_dp.append(line_bb[9])
         ev_date.append(line_bb[10])

df_ev = pd.DataFrame(list(zip(ev_yr,ev_mo,ev_da,ev_ho,ev_mn,ev_sc,ev_ms,ev_la,ev_lo,ev_dp,ev_date)), columns =['year','month','day','hour','minute','second','msecond','lat','lon','depth','date'])
print(df_ev)
df_ev=df_ev.drop_duplicates(subset=['year', 'month','day','hour','minute','second','msecond'], keep='last')
#df_ev=df_ev.iloc[189]
print(df_ev)
#Construct list of BH stations
infile_bh_aus="../BH_AUSPASS.txt"
infile_bh_iris="../BH_IRIS.txt"

net_bh=[]
sta_bh=[]
stla_bh=[]
stlo_bh=[]
stel_bh=[]

#SPLIT TO TWO COLUMNS
for infile_bh in (infile_bh_aus, infile_bh_iris):
   with open (infile_bh) as filein:
       for line_aa in filein.readlines():
           line_aa = line_aa.strip()
           line_bb = line_aa.split(' ')
           net_bh.append(line_bb[0])
           sta_bh.append(line_bb[1])
           stla_bh.append(line_bb[2])
           stlo_bh.append(line_bb[3])
           stel_bh.append(line_bb[4])

df_bh = pd.DataFrame(list(zip(net_bh,sta_bh,stla_bh,stlo_bh,stel_bh)), columns =['network', 'station', 'stlat', 'stlon', 'stel'])
print (df_bh)
df_bh=df_bh.drop_duplicates(subset=['network', 'station'], keep='first')
print (df_bh)


#Construct list of HH stations
infile_hh_aus="../HH_AUSPASS.txt"
infile_hh_iris="../HH_IRIS.txt"

net_hh=[]
sta_hh=[]
stla_hh=[]
stlo_hh=[]
stel_hh=[]

#SPLIT TO TWO COLUMNS
for infile_hh in (infile_hh_aus, infile_hh_iris):
   with open (infile_hh) as filein:
       for line_aa in filein.readlines():
           line_aa = line_aa.strip()
           line_bb = line_aa.split(' ')
           net_hh.append(line_bb[0])
           sta_hh.append(line_bb[1])
           stla_hh.append(line_bb[2])
           stlo_hh.append(line_bb[3])
           stel_hh.append(line_bb[4])


df_hh = pd.DataFrame(list(zip(net_hh,sta_hh,stla_hh,stlo_hh,stel_hh)), columns =['network', 'station', 'stlat', 'stlon', 'stel'])
print (df_hh)
df_hh=df_hh.drop_duplicates(subset=['network', 'station'], keep='first')
print (df_hh)

print (os.getcwd())
current_directory = os.getcwd()
#for directory in glob.glob('20*'):
#   os.chdir(directory)
#   print (os.getcwd())


one_mseed=glob.glob('*mseed')[0]
st_one = read(one_mseed)
tr=st_one[0]

print ("----")
print ((str( ("{:04d}".format(tr.stats.starttime.year)) )), (str( ("{:02d}".format(tr.stats.starttime.month)) )), (str( ("{:02d}".format(tr.stats.starttime.day)) )), (str( ("{:02d}".format(tr.stats.starttime.hour)) )), (str( ("{:02d}".format(tr.stats.starttime.minute)) )),  (str( ("{:02d}".format(tr.stats.starttime.second)) )) )
print ("----")

evt = df_ev[(df_ev['year']==str( ("{:04d}".format(tr.stats.starttime.year)) )) & (df_ev['month']==str( ("{:02d}".format(tr.stats.starttime.month)) )) & (df_ev['day']==str( ("{:02d}".format(tr.stats.starttime.day)) )) & (df_ev['hour']==str( ("{:02d}".format(tr.stats.starttime.hour)) )) & (df_ev['minute']==str( ("{:02d}".format(tr.stats.starttime.minute)) )) & (df_ev['second']==str( ("{:02d}".format(tr.stats.starttime.second)) ))]


print ("--- print match here ---")
print (evt)


print (evt)
if evt.empty:
   print ("Event not found in catalogue. SKIPPING")
   sys.exit()
evlat=float(evt['lat'].values)
evlon=float(evt['lon'].values)
evdep=float(evt['depth'].values)
print(evlat, evlon, evdep)

#     elat=0
#     elon=0
#     edep=0


for file in glob.glob('*mseed'):
  print (file)
  st = read(file)
  print(st) 


  print (st.count())
  if (st.count()) == 3:
     for tr in st[:]:
        print(tr)
        #tr.filter("bandpass", freqmin = f1, freqmax = f2, corners=corn, zerophase=filtphase)
        #tr.taper(0.05)

        #print(dir(tr.stats))
        print (tr.stats.network, tr.stats.station, tr.stats.channel)
        if "HH" in tr.stats.channel:
           print ("HH")
           sta = df_hh[(df_hh['network']==str(tr.stats.network)) & (df_hh['station']==str(tr.stats.station))]
        elif "BH" in tr.stats.channel:
           print ("BH")
           sta = df_bh[(df_bh['network']==str(tr.stats.network)) & (df_bh['station']==str(tr.stats.station))]

        print ("df_sta",sta)   
        stlat=float(sta['stlat'].values)
        stlon=float(sta['stlon'].values)
        stel=float(sta['stel'].values)
        #print (df_bh) 

#/   home/dfrost/Work/Pdiff/200909020755_new2020_SAC_BHR/200909020755.AZ.FRD.BHR.sac
        date=str(file)[-25:-8]
        date=date.replace('-','')
        date=date.replace('_','')



        #SAC header
        sachdr = {
            'evla': evlat,
            'evlo': evlon,
            'evdp': evdep,
            'stla': stlat,
            'stlo': stlon,
            'stel': stel}


        tr.stats.sac=sachdr
     
     #for ti in st:
        if str(tr.stats.channel[-1]) == 'E':
            te = tr
        elif str(tr.stats.channel[-1]) == 'N':
            tn = tr
        elif str(tr.stats.channel[-1]) == 'Z':
            tz = tr
        elif str(tr.stats.channel[-1]) == '1':  
            t1 = tr
            tn = tr
        elif str(tr.stats.channel[-1]) == '2':  
            t2 = tr
            te = tr

     # Rotate N-E to R-T
     print(evlat, evlon, stlat,stlon)
     [res,az,baz]=gps2dist_azimuth( evlat, evlon, stlat,stlon)
     if az > 180:
         az=az-360
     
     try:    
        [tn.data,te.data] = rotate.rotate_ne_rt(tn.data,te.data,baz)
     except:
        continue
     te.stats['channel'] = te.stats['channel'][:-1]+'T'
     tn.stats['channel'] = tn.stats['channel'][:-1]+'R'


     print (date)
     #msg = "%s converted to %s.%s.%s.sac" % (str(file), tr.stats.station, tr.stats.channel, str(file)[9:18])
     msg = "%s converted to %s.%s.%s.%s.sac" % (str(file), date,tr.stats.network,tr.stats.station, tr.stats.channel)
     sacname = "%s.%s.%s." % (date,tr.stats.network,tr.stats.station)
     print(msg)


     tn.stats.sac=sachdr
     te.stats.sac=sachdr
     tz.stats.sac=sachdr
     tn.write(sacname+tn.stats['channel']+'.sac', format='sac')
     te.write(sacname+te.stats['channel']+'.sac', format='sac')
     tz.write(sacname+tz.stats['channel']+'.sac', format='sac')
     
#os.chdir(current_directory)



