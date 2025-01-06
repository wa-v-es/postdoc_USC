### plots mean baz offset for each Earthquake, either for pacific or SA.
# change lines where matching_files_pa/matching_files_sa are used in the script.
#
import obspy
# import miller_alaskamoho_srl2018 as alaskamoho
import os.path as path
import numpy as np
import matplotlib.ticker as mticker
import glob as glob
from cmcrameri import cm
import matplotlib.pyplot as plt
import matplotlib.path as mpath
from matplotlib.lines import Line2D
from matplotlib.patches import Patch
import sys
import re
######

folder_pattern_pa = "/Users/keyser/Research/AK_all_stations/sac_files/max_vals_coherence/*maxVals_low_slow.txt"
folder_pattern_sa = "/Users/keyser/Research/AK_all_stations/sac_files/max_vals_coherence/SA/*maxVals_low_slow.txt"

matching_files_pa = sorted(glob.glob(folder_pattern_pa))
print('length of files in low slow folder=',len(matching_files_pa),'\n')
matching_files_sa = sorted(glob.glob(folder_pattern_sa))
###
#contains grid number; baz at max coherence va; mean of peaks;std of peaks; array cen lat long elevation

# fig = plt.figure(figsize=(14, 9)) # for PA
fig = plt.figure(figsize=(6, 9))

ax1 = fig.add_axes([0.07, 0.2, 0.88, 0.35]) #[left, bottom, width, height]
plt.ion()
plt.style.use('seaborn-v0_8-whitegrid')

i=0
tick_labels=[]
for eq_file in matching_files_sa:
    i+=1
    bb = re.search(r'max_vals_coherence/SA/([^_]+)', eq_file)
    tick_labels.append(bb.group(1))
    for line in open(eq_file,'r'):
        line=line.split()

        if float(line[2]) > .6:
            # ax1.scatter(float(line[5]),float(line[4]),s=50)
            # ax1.scatter(i,float(line[1]),s=70,marker='d',facecolor='rebeccapurple', edgecolor='black',alpha=.35,linewidth=.75,zorder=10)
            ax1.errorbar(i,float(line[2]), yerr=float(line[3]),ecolor='black',marker='o', alpha=.25,markerfacecolor='rebeccapurple', markeredgecolor='black',markersize=8,linestyle='none')
        if -.6 < float(line[2]) < .6:
            ax1.errorbar(i,float(line[2]), yerr=float(line[3]),ecolor='grey',marker='o', alpha=.25,markerfacecolor='white', markeredgecolor='black',markersize=5,linestyle='none')
        if float(line[2]) < -.6:
            ax1.errorbar(i,float(line[2]), yerr=float(line[3]),ecolor='grey',marker='o', alpha=.25,markerfacecolor='seagreen', markeredgecolor='black',markersize=8,linestyle='none')
ax1.set_ylim(-12,12)
ax1.set_xticks(range(1, len(matching_files_sa) + 1))
ax1.set_xticklabels(tick_labels,rotation=45, ha='center')
plt.rcParams['axes.labelsize'] = 15
ax1.set_ylabel('Mean Baz offset ($^\circ$) low slow')
ax1.set_xlabel('Earthquakes South America',labelpad=15)
ax1.tick_params(axis='x', labelsize=11)
ax1.tick_params(axis='y', labelsize=12)

# ax1.set_title('Baz mean offset low slowness PA')
###
folder_pattern_pa = "/Users/keyser/Research/AK_all_stations/sac_files/max_vals_coherence/*maxVals_high_slow.txt"
folder_pattern_sa = "/Users/keyser/Research/AK_all_stations/sac_files/max_vals_coherence/SA/*maxVals_high_slow.txt"
matching_files_pa = sorted(glob.glob(folder_pattern_pa))
print('length of files in high slow folder=',len(matching_files_pa),'\n')
matching_files_sa = sorted(glob.glob(folder_pattern_sa))
i=0
tick_labels=[]
ax2 = fig.add_axes([0.07, 0.55, 0.88, 0.35]) #[left, bottom, width, height]
# ax2.sharex(ax1)

for eq_file in matching_files_sa:
    i+=1
    bb = re.search(r'max_vals_coherence/SA/([^_]+)', eq_file)
    tick_labels.append(bb.group(1))
    for line in open(eq_file,'r'):
        line=line.split()

        if float(line[2]) > .6:
            # ax1.scatter(float(line[5]),float(line[4]),s=50)
            # ax1.scatter(i,float(line[1]),s=70,marker='d',facecolor='rebeccapurple', edgecolor='black',alpha=.35,linewidth=.75,zorder=10)
            ax2.errorbar(i,float(line[2]), yerr=float(line[3]),ecolor='black',marker='o', alpha=.25,markerfacecolor='rebeccapurple', markeredgecolor='black',markersize=8,linestyle='none')
        if -.6 < float(line[2]) < .6:
            ax2.errorbar(i,float(line[2]), yerr=float(line[3]),ecolor='grey',marker='o', alpha=.25,markerfacecolor='white', markeredgecolor='black',markersize=5,linestyle='none')
        if float(line[2]) < -.6:
            ax2.errorbar(i,float(line[2]), yerr=float(line[3]),ecolor='grey',marker='o', alpha=.25,markerfacecolor='seagreen', markeredgecolor='black',markersize=8,linestyle='none')
ax2.set_ylim(-12,12)
ax2.set_xticks(range(1, len(matching_files_sa) + 1))
# ax2.xaxis.set_label_position('top')
# ax2.set_xticklabels(tick_labels,rotation=45, ha='right')
ax2.tick_params(axis='y', labelsize=12)
ax2.set_xticklabels([])
ax2.set_ylabel('($^\circ$) high slow')
plt.savefig('SA_eq_mean.png',dpi=300,bbox_inches='tight', pad_inches=0.1)
# plt.show()
