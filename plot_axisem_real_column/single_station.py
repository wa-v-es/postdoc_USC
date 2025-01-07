## this script compares the synthetic and real seismograms.
# synthetic computed using axisem3d
###
import os
import yaml
import numpy as np

import matplotlib.pyplot as plt
from mpl_toolkits.basemap import Basemap
import matplotlib
import sys
matplotlib.rcParams.update({'font.size': 8})
from obspy import read
from obspy.core import Stream, Trace, UTCDateTime, Stats
from obspy.io.sac import SACTrace
from obspy.io.sac.util import get_sac_reftime
from obspy.taup import TauPyModel
from obspy.taup.taup_geo import calc_dist,calc_dist_azi

########
input_dir='/Users/keyser/Research/axisem/loyalty_isl/input'
syn_dir = '/Users/keyser/Research/axisem/loyalty_isl/output/stations/AK_81/sac/'
info_5deg = np.loadtxt(input_dir+'/ak_81_220914_110406.txt', dtype=str, skiprows=3)
iris_seis = '/Users/keyser/Research/AK_all_stations/sac_files/220914_110406_PA_inc2_r2.5/'


with open(input_dir+'/inparam.source.yaml', 'r') as file:
    source_yaml = yaml.load(file, Loader=yaml.FullLoader)
loc_leaf = source_yaml['list_of_sources'][0]['loyaltyIsl_20220914_110406']['location']
event_latlon = loc_leaf['latitude_longitude']
event_depth = loc_leaf['depth']
###
# starttime=ori.time+arr_PP.time-400 for st_iris
all_syn=Stream()
all_iris=Stream()

for ist, st in enumerate(info_5deg):
    print('%d / %d' % (ist + 1, len(info_5deg)), end='\r')
    st_name=st[0]
    # st_name='MCK'
    st_syn=read(syn_dir+'*{}.Z.sac'.format(st_name))
    st_iris=read(iris_seis+'*{}.*Z.sac'.format(st_name))
    origin_time = get_sac_reftime(st_iris[0].stats.sac)
    st_syn[0].stats.starttime=origin_time

    #### to align the seismograms

    model = TauPyModel(model="ak135")
    arrivals = model.get_travel_times(source_depth_in_km=st_iris[0].stats.sac['evdp']/1000,distance_in_degree=st_iris[0].stats.sac['gcarc'],phase_list=["PP"])
    arr_PP=arrivals[0]

    st_syn.trim(starttime=origin_time+arr_PP.time-400,endtime=origin_time+arr_PP.time+200)
    st_iris.filter('lowpass',freq=1/20)
    # st_iris[0].data=7*st_iris[0].data
    # stream_both = Stream(traces=[st_syn[0], st_iris[0]])

    all_syn.append(st_syn[0])
    all_iris.append(st_iris[0])
##
model = TauPyModel(model="ak135")
dist_azi_bazi=calc_dist_azi(-21.19,170.27,61.1416, -148.1751,6400,0)
print(dist_azi_bazi)
arrivals = model.get_travel_times(source_depth_in_km=st_iris[0].stats.sac['evdp']/1000,distance_in_degree=st_iris[0].stats.sac['gcarc'],phase_list=['P','pP','sP',"PP"])
plt.ion()

# plot synthetic with P, S, and other phases.
fig, ax = plt.subplots(2, sharex=True, dpi=150)
# for ich, ch in enumerate('RTZ'):
#     # change unit to mm
ax[0].xaxis_date()
ax[1].xaxis_date()
ax[0].plot(st_iris[0].times("utcdatetime"), st_iris[0].data, lw=.8,c='cadetblue', label='real')
ax[1].plot(st_syn[0].times("utcdatetime"), st_syn[0].data, lw=.8,c='indianred' ,label='syn')
for i in range(len(arrivals)):
    ax[1].scatter(origin_time+arrivals[i].time,0,s=17,marker='d',facecolor='rebeccapurple', edgecolor='black',alpha=.5,linewidth=.75,zorder=10)
    ax[0].scatter(origin_time+arrivals[i].time,0,s=17,marker='d',facecolor='rebeccapurple', edgecolor='black',alpha=.5,linewidth=.75,zorder=10)

#

fig.autofmt_xdate()
plt.legend()
plt.show()
sys.exit()

# ax[1].text(.95, .2, 'channel = ' + ch, transform = ax[ich].transAxes, ha='right', va='top')
# ax[1].set_ylabel('Amplitude (mm)')
# ax[0].set_xlim(time[0], time[-1])
# plt.xlabel('Time after source origin (s)')
##
#cd '/Users/keyser/Research/axisem/forPC_output/stations/5deg_array/sac'
st=read('*long80.Z.sac')
arrivals = model.get_travel_times(source_depth_in_km=600,distance_in_degree=80,phase_list=['P','pP','sP',"PP"])
fig = plt.figure(figsize=(11,8))
st.plot(color='cadetblue',bgcolor='ivory', fig=fig, orientation="horizontal")
for i in range(len(arrivals)):
    plt.scatter(st[0].stats.starttime+arrivals[i].time,0,s=37,marker='o',facecolor='rebeccapurple',alpha=.95,zorder=10)
plt.show()
