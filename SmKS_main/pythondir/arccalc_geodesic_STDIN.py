#Python Script
#Reads Lat1, Lon1, Distance, Azimuth
#Prints Lat1, Lon1 Distance, Azimuth, Lat2, Lon2


import numpy as np
import math as m
import sys
from geographiclib.geodesic import Geodesic


#INPUT
lat1 = float(sys.argv[1]) #Lat_src
lon1 = float(sys.argv[2]) #Lon_src
dist = float(sys.argv[3]) #Dist (deg)
azi = float(sys.argv[4]) #Azi
 

geodesicd=Geodesic.WGS84.ArcDirect(lat1, lon1, azi, dist)
lat2=geodesicd.get("lat2","none")
lon2=geodesicd.get("lon2","none")

#print '{0:8.4f} {1:8.4f} {2:8.4f} {3:8.4f} {4:8.4f} {5:8.4f} {6:8.4f}'.format(col1, col2, col3, col4, dist, azi, bazi)
print('{0:8.4f} {1:8.4f}'.format(lat2, lon2))

