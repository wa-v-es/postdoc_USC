import numpy as np
from scipy.signal import argrelextrema
#from scipy.interpolate import interp1d
import sys

winlen=13
#-------------
def smooth(x,window_len=winlen,window='hanning'):
    """smooth the data using a window with requested size.
    
    This method is based on the convolution of a scaled window with the signal.
    The signal is prepared by introducing reflected copies of the signal 
    (with the window size) in both ends so that transient parts are minimized
    in the begining and end part of the output signal.
    
    input:
        x: the input signal 
        window_len: the dimension of the smoothing window; should be an odd integer
        window: the type of window from 'flat', 'hanning', 'hamming', 'bartlett', 'blackman'
            flat window will produce a moving average smoothing.

    output:
        the smoothed signal
        
    example:

    t=linspace(-2,2,0.1)
    x=sin(t)+randn(len(t))*0.1
    y=smooth(x)
    
    see also: 
    
    numpy.hanning, numpy.hamming, numpy.bartlett, numpy.blackman, numpy.convolve
    scipy.signal.lfilter
 
    TODO: the window parameter could be the window itself if an array instead of a string
    NOTE: length(output) != length(input), to correct this: return y[(window_len/2-1):-(window_len/2)] instead of just y.
    """ 
     
    if x.ndim != 1:
        raise ValueError("smooth only accepts 1 dimension arrays.")

    if x.size < window_len:
        raise ValueError("Input vector needs to be bigger than window size.")
        

    if window_len<3:
        return x
    
    
    if not window in ['flat', 'hanning', 'hamming', 'bartlett', 'blackman']:
        raise ValueError("Window is on of 'flat', 'hanning', 'hamming', 'bartlett', 'blackman'")
    

    s=np.r_[x[window_len-1:0:-1],x,x[-1:-window_len:-1]]
    #print(len(s))
    if window == 'flat': #moving average
        w=np.ones(window_len,'d')
    else:
        w=eval('np.'+window+'(window_len)')
    
    y=np.convolve(w/w.sum(),s,mode='valid')
    return y    

#-------------

#INPUTS
startfile=sys.argv[1]

#READ START POINT COLUMNS FROM $startfile
st_colu1 = [] #Node_num
st_colu2 = [] #Node_lat
st_colu3 = [] #Node_lon


with open (startfile) as filestart:
    for line_aa in filestart.readlines():
         line_aa = line_aa.strip()
#         print line_aa
         col1,col2,col3 = line_aa.split(' ',3)
         st_colu1.append(float(col1)) #Lat_start
         st_colu2.append(float(col2)) #Lat_start
         st_colu3.append(float(col3)) #Lon_start

#interp_func=interp1d(st_colu1, st_colu3)
#st_colu3_interp=interp_func(st_colu1)

st_colu3_interp=np.transpose(smooth(np.transpose(st_colu3),window_len=winlen,window='flat'))
st_colu3_interp=st_colu3_interp[int((winlen-1)/2):(len(st_colu3_interp)-int((winlen-1)/2))]
#print len(st_colu3_interp)
#print len(st_colu1)
#print len(st_colu2)
#dif_arr=np.column_stack((st_colu1,st_colu2,st_colu3))
dif_arr=np.column_stack((st_colu1,st_colu2,st_colu3_interp))

#a=np.transpose(st_colu3)
a=np.transpose(st_colu3_interp)


#print dif_arr

# for local maxima
max_mask=(argrelextrema(a, np.greater)[0])
max_mask=max_mask[-1]
max_ind=(dif_arr[int(max_mask),:])
#DEBUG print max_mask[-1]
#print max_ind

# for local minima
min_mask=(argrelextrema(a, np.less)[0])
min_mask=min_mask[-1]
min_ind=(dif_arr[int(min_mask),:])
#DEBUG print min_mask
#print min_ind

if(min_mask>max_mask):
    max_mask_SV=max_mask
    min_mask=max_mask
    max_mask=max_mask_SV


dif_arr_cut=dif_arr[int(min_mask):(int(max_mask)+1),:]

#dif_arr_cut[:,4]=np.divide((np.subtract(dif_arr_cut[:,2],min_ind[2])),(max_ind[2]-min_ind[2]))
dif_arr_cut_norm=np.divide((np.subtract(dif_arr_cut[:,2],min_ind[2])),(max_ind[2]-min_ind[2]))
dif_arr_cut=np.column_stack((dif_arr_cut[:,:],dif_arr_cut_norm))
#DEBUG print dif_arr_cut
thres1=(np.where(dif_arr_cut[:,3]>=0.5))
#DEBUG print "----"
print((dif_arr_cut[thres1])[0,0], (dif_arr_cut[thres1])[0,1], (dif_arr_cut[thres1])[0,2], (dif_arr_cut[thres1])[0,3])


