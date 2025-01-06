#Python Script
#Read in array from file


import numpy as np
import math as m
import sys
from geographiclib.geodesic import Geodesic

#INPUTS
infile=sys.argv[1]  #Lat_scat, Lon_scat Lat_src, Lon_src, Dist_up
outfile=sys.argv[2] #Lat_scat, Lon_scat, Dist_down, Dist_up


#INPUT
col1 = float(sys.argv[1]) #Lat_src
col2 = float(sys.argv[2]) #Lon_src
col3 = float(sys.argv[3]) #Lat_rec 
col4 = float(sys.argv[4]) #Lon_rec 
 

geodesicd=Geodesic.WGS84.Inverse(col1, col2, col3, col4)
dist=geodesicd.get("a12","none")
azi=geodesicd.get("azi1","none")
geodesicd=Geodesic.WGS84.Inverse(col3, col4, col1, col2)
bazi=geodesicd.get("azi1","none")
#print '{0:8.4f} {1:8.4f} {2:8.4f} {3:8.4f} {4:8.4f} {5:8.4f} {6:8.4f}'.format(col1, col2, col3, col4, dist, azi, bazi)
print('{0:8.4f} {1:8.4f} {2:8.4f}'.format(dist, azi, bazi))
