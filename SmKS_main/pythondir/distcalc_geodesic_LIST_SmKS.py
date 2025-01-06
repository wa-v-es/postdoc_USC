#Python Script
#Read in array from file


import numpy as np
import math as m
import sys
from geographiclib.geodesic import Geodesic

#INPUTS
infile=sys.argv[1]  #Lat_scat, Lon_scat Lat_src, Lon_src, Dist_up
outfile=sys.argv[2] #Lat_scat, Lon_scat, Dist_down, Dist_up


#READ COLUMNS FROM $infile
colu1 = [] #Lat_scat
colu2 = [] #Lon_scat
colu3 = [] #Lat_src 
colu4 = [] #Lon_src 


col_dist = []
col_azi = []
col_bazi = []

#colu5 = [] #Dist_up 


with open (infile) as filein:
    for line_aa in filein.readlines():
         line_aa = line_aa.strip()
         #print line_aa
         col1,col2,col3,col4 = line_aa.split(' ',4)
         colu1.append(float(col1)) #Lat_scat
         colu2.append(float(col2)) #Lon_scat
         colu3.append(float(col3)) #Lat_src 
         colu4.append(float(col4)) #Lon_src 
#         colu6.append(float(col6))
#         colu5.append((col5)) #Station name
#         colu6.append((col6))
         #colu5.append(float(col5)) #Dist_up (scat-array)

for lat1, lon1, lat2, lon2 in zip(colu1, colu2, colu3, colu4):
#    print (lat1, lon1, lat2, lon2)
    geodesicd=Geodesic.WGS84.Inverse(lat1, lon1, lat2, lon2)
    dist=geodesicd.get("a12","none")
    azi=geodesicd.get("azi1","none")
    geodesicd=Geodesic.WGS84.Inverse(lat2, lon2, lat1, lon1)
    bazi=geodesicd.get("azi1","none")
#   print dist, azi
    col_dist.append(dist)
    col_azi.append(azi)
    col_bazi.append(bazi)


#Lat1, Lon1, Lat2, Lon2, Dist, Azi
#np.savetxt(outfile, np.column_stack((colu1,colu2,colu3,colu4,col_dist,col_azi,colu5, colu6)), fmt=('%8.4f', '%8.4f', '%8.4f', '%8.4f', '%8.4f', '%8.4f', '%.7f', '%2d'));

np.savetxt(outfile, np.column_stack((colu1,colu2,colu3,colu4,col_dist,col_azi)), fmt=('%8.4f', '%8.4f', '%8.4f', '%8.4f', '%8.4f', '%8.4f'));
