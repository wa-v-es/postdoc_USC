#! /bin/bash
#Loops over base station location across TA and puts in to Vespa_TA_SKKS_Padap.bsh
#Dan A Frost
#20.3.2015
#ASU
alias sed='/opt/homebrew/bin/gsed'
shopt -s expand_aliases


#===========
#Description
#===========
#This is the wrapper script
#Within the pwd this code will search for sac files, and loop over them.
#FOR LOOP over a 1x1 degree grid of lats and lons, search for stations around that centre lat,lon and try to construct a subarray using those stations
#IF there are enough stations (greater than or equal to $number) then the code will run the F-pack
#IF the subarray is within the appropriate distance range for a phase (lim_lower_S*KS to lim_upper_S*KS) the F-pack will be run for that phase, for that subarray
#Selects base station to be the central station of the subarray
#Only allows each station to be a base station once, stores used base stations in $basestation_var


#=================
#Run instructions:
#=================
#1. cd to a directory containing: sacfiles
#2. Run SmKS_TA_Diamondsearch_Vespapack_F90_EQ1_UD2020_LOOPER_NOPadap.bsh
#2. OPTIONAL: $skippingto=$1     which skips the LOOP1 to a given subarray number (DEFAULT=1)
#2. OPTIONAL: $comp=$2           sets the component to use (R/T/Z)                (DEFAULT=R)
#   SmKS_TALooper_2020.bsh $skippingto $comp
#NOTES: this code should run over all subarrays for a given event, so it can take several days to complete

#SmKS_TALooper_2020.sh 1 Z AK_whole obs

#=============
#Codes needed:
#=============
#python3 ~/Work/Python/distcalc_geodesic_STDIN.py
#python3 ~/Work/Python/distcalc_geodesic_LIST_SmKS.py
#python3 ~/Work/Python/local_minima_find.py
#sac
#sac2xy


#========
#Outputs:
#========
#For each EVENT/DIRECTORY/RUN OF SmKS_TALooper_2020.bsh
#1. Basestation_Array."$eventdate"_SKScd.dat - List of base stations and whether they were used or skipped
#2. TA_SubArray_SmKS_Search_"$eventdate"_SKS*.dat" - List of measured arrival times, slownesses, back-azimuths, and stations used to form beam for subarray

#For each SUBARRAY and PHASE form running SmKS_Vespapack_2020.bsh
#1. "Vespapack_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base"$grid_num"spl"$splitnum"_num"$number_used"_SKS_F90_"$plane_corr".ps" - Output plot that shows F-vespagrams, beam-vespagrams, and record section.
#2. "Vespapack_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base"$grid_num"spl"$splitnum"_num"$number_used"_SKS_F90_"$plane_corr"_RECORD.ps" - Output plot that shows the waveforms and with F-vespagrams better
#3. "VespapackBeam_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base"$grid_num"spl"$splitnum"_num"$number_used"_SKS_F90_"$plane_corr"_RECORD.ps" - Output plot that shows the waveforms and with beam-vespagrams better
#4.  "Datapack_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base"$grid_num"spl"$splitnum"_num"$number_used"_SKIKS_F90_"$plane_corr".txt" - information used to plot the record RECORD.ps files (not very useful otherwise)


#=============
#Known issues:
#=============
#    -HOW IT SHOWS UP-      -CAUSE-                                           -FIX-
# 1) Code stopts at F-trace - 1 sac file in array with zeros/wrong time/error - Cancel code, remove sac file with error, add station name to "stations_to_remove.$eventdate list, run code again starting at last grid_num

# 2) Onset picked too early - maximum amplitude for phase not within picking box - No current fix, maybe rerun with different $timerange1/2 values, or changing picking code

# 3) Onset picked at wrong time - local minima in gradient                     -No current fix, maybe add smoothing to gradient, or change picking code

##
echo $PATH

#===========
#Command Line Inputs
#===========
#Code will loop through a grid and count each grid point, starting at 1
skippingto=${1-1} #This line reads STDIN col1, use this to skip to a given array number
comp=${2-R}
region=${3-US}
datatype=${4-obs}

#===========
#Directories
#===========
#####
# use this to run all folders in sac_files
#
# for folder in `ls`; do
# cd $folder

mkdir grid_folder
mkdir st_files
mkdir data_pack
mkdir xf_beam_record
mkdir st_imgs
mkdir py_picks
mkdir py_figs



home_dir=/Users/keyser/Documents/softies/SmKS-main
#source $home_dir"/MWE_bashrc"
export data_dir=$home_dir"/"
export scripts_dir=$home_dir"/scriptsdir/"
export bin_dir=$home_dir"/bin/"
export fpack_dir=$home_dir"/Fpack_2020/"
export ftrace_dir=$home_dir"/Ftrace_2020/"
export temps=$home_dir"/temps/"
export monitoring=$home_dir"/SmKS_monitoring/"
export work=`pwd | sed 's/$/\//g'`
if [ $datatype == "obs" ]; then
    export beamdir=$work"/Beam_traces_BH"$comp"/"
elif [ $datatype == "synthB" ]; then
    export beamdir=$work"/Beam_traces_BX"$comp"/"
elif [ $datatype == "synthM" ]; then
    export beamdir=$work"/Beam_traces_MX"$comp"/"
fi

#===========
#Programs
#===========
export py3=/usr/bin/python3
export pydir=/Users/keyser/Documents/softies/SmKS-main/pythondir/



#===========
#Files
#===========
eventdate=`pwd | awk -F "/" '{print $NF}' | cut -f1 -d"_"`
touch stations_to_remove.$eventdate


#===========
#Checks for data and dependencies
#===========
#Check for data # change here for SP/BB/input data type
if [ $datatype == "obs" ]; then
    export sacroot="H"$comp".sac"
    export comproot=H
elif [ $datatype == "synthB" ]; then
    export sacroot="BX"$comp".sem.sac"
    export comproot=BX
elif [ $datatype == "synthM" ]; then
    export sacroot="MX"$comp".sem.sac"
    export comproot=MX
fi

if [ `ls *$sacroot | awk 'END {print NR}'` -le 1 ]; then
echo "NO SAC FILES IN PWD! STOPPING".
echo "CD TO DIRECTORY WITH SACFILES (e.g. eventsdir/200910072141) AND RUN AGAIN"
exit
else
echo "SAC FILES EXIST. CONTINUE."
fi

#Check for dependencies
if ! [ -x "$(command -v sac2xy)" ]; then
  echo 'Error: sac2xy is not installed.' >&2
  exit 1
else
	echo sac2xy installed
fi

#Check for dependencies
if ! [ -x "$(command -v fpack_rnorm_tmin_circ_elv_f90)" ]; then
  echo 'Error: fpack is not installed.' >&2
  exit 1
else
	echo fpack installed
fi

#Check for dependencies
if ! [ -x "$(command -v ftrace_rnorm_tau_tmin_circ_elv_f90)" ]; then
  echo 'Error: ftrace is not installed.' >&2
  exit 1
else
	echo ftrace installed
fi

#Check for dependencies
if ! [ -x "$(command -v sac2xy)" ]; then
  echo 'Error: sac2xy is not installed.' >&2
  exit 1
else
	echo sac2xy installed
fi

#Check for dependencies
if ! [ -x "$(command -v sachead)" ]; then
  echo 'Error: sachead is not installed.' >&2
  exit 1
else
	echo sachead installed
fi

#Check for dependencies
if ! [ -x "$(command -v radiation_thaz)" ]; then
  echo 'Error: radiation_thaz is not installed.' >&2
  exit 1
else
	echo radiation_thaz installed
fi

#Check for dependencies
if ! [ -x "$(command -v $py3)" ]; then
  echo 'Error: py3 is not installed.' >&2
  exit 1
else
	echo py3 installed
fi

#Check for dependencies
if ! [ -x "$(command -v sac)" ]; then
  echo 'Error: sac is not installed.' >&2
  exit 1
else
        echo sac installed
fi

#Check for dependencies
if ! [ -x "$(command -v taup)" ]; then
  echo 'Error: taup is not installed.' >&2
  exit 1
else
        echo taup installed
fi

#Check for dependencies
if ! [ -x "$(command -v gmt)" ]; then
  echo 'Error: gmt is not installed.' >&2
  exit 1
else
        echo gmt installed
fi


##
#===========
#Phase Options
#===========
#Distance limits (array centre must be between these limits)
#Input list of phases to run
#Format: Phasename, TaupPhasename Lower_distance_limit Upper_distance_limit

#TO ADD - when ready to run all phases, remove comments from the block below
#cat<<EOF>$work"Input_Phase_List_"$$
#S S 50 96
#SKScd SKiKS 80 120
#SKIKS SKIKS 142 160
#PKS PKS 131 145
#Sdiff Sdiff 97 170
#SKS SKS 62 142
#SKKS SKKS 85 170
#S3KS SKKKS 110 175
#S4KS SKKKKS 130 175
#EOF


#TO REMOVE - when ready to run all phaes, add comments/delete the writing of "Input_Phase_List_"$$  below
cat<<EOF>$work"Input_Phase_List_"$$
PP PP 60 130
EOF

phase_list=(`awk '{print $1}' $work"Input_Phase_List_"$$`)
taupphase_list=(`awk '{print $2}' $work"Input_Phase_List_"$$`)

#Upper and lower distance limits for all phases
lim_lower_ALL=`awk '{print $3}' $work"Input_Phase_List_"$$ | sort -nk1 | awk 'NR==1 {print $1}'`
lim_upper_ALL=`awk '{print $4}' $work"Input_Phase_List_"$$ | sort -nrk1 | awk 'NR==1 {print $1}'`


#===========
#Fpack Options
#===========
DO_CIRC=Y #Circular wave (Y)/Plane wave (N)
DO_ELEV=N #Station elevation correction (Y/N) - Applys a correction for the differential station heights in Fpack and Ftrace.
#Uses crustal velocity of 3kms-1. Assumes vertical wave propagation, i.e. uses only elevation, not elevation and incidence angle.
elev_vel=3.0 #Velocity for elevation correction
DO_RADPAT=Y #Normalise to radpat (Y/N)


#SLOWNESS AND BACK-AZIMUTH LIMITS AND INCREMENTS FOR VESPAPACK
#SLOWNESS VALUES CAN BE FLOATS, BACK-AZIMUTH HAS TO BE INTEGERS
#gridtype=full
gridtype=full
if [ $gridtype == "test" ]; then
  slo_min=0.0; slo_inc=0.5; slo_max=10.0
  baz_min=-50; baz_inc=4; baz_max=50
elif [ $gridtype == "full" ]; then
  slo_min=0; slo_inc=0.2; slo_max=10.0
  baz_min=-50; baz_inc=2; baz_max=50
fi

#Filtering: min, max, number of samples to use in F-trace window
if [ $datatype == "obs" ]; then
    fmin=.05;fmax=.5; delta=60
    #fmin=0.04;fmax=0.5; delta=60
elif [ $datatype == "synthM" ]; then
    fmin=0.02; fmax=0.083; delta=60
elif [ $datatype == "synthB" ]; then
    fmin=0.02; fmax=0.083; delta=60
fi


#===========
#Grid Options
#===========
grid_num=1 #Sets array counter back to 1 at the start of the grid

if [ $region == "ILAR" ]; then
      grid_lat_min=64; grid_lat_max=65        #Range of lats to search and form subarrays # for subarray around ILAR
      grid_lon_min=-147; grid_lon_max=-146   #Range of lons to search and form subarrays

elif [ $region == "AlSub" ]; then
      grid_lat_min=63; grid_lat_max=66        #Range of lats to search and form subarrays # for subarray around ILAR
      grid_lon_min=-150; grid_lon_max=-144   #Range of lons to search and form subarrays

  elif [ $region == "GRSN" ]; then
        grid_lat_min=47.5; grid_lat_max=54.75        #Range of lats to search and form subarrays # for subarray around ILAR
        grid_lon_min=6; grid_lon_max=14.5   #Range of lons to search and form subarrays

elif [ $region == "AK_whole" ]; then
      grid_lat_min=55; grid_lat_max=73        #Range of lats to search and form subarrays # for subarray around ILAR
      grid_lon_min=-169; grid_lon_max=-137   #Range of lons to search and form subarrays

elif [ $region == "AlSub_sm" ]; then
      grid_lat_min=64; grid_lat_max=66        #Range of lats to search and form subarrays # for subarray around ILAR
      grid_lon_min=-150; grid_lon_max=-146   #Range of lons to search and form subarrays

elif [ $region == "AlSub_sm_W" ]; then
      grid_lat_min=64.5; grid_lat_max=66        #Range of lats to search and form subarrays # for subarray around ILAR
      grid_lon_min=-152; grid_lon_max=-147.8

elif [ $region == "AlSub_sm_N" ]; then
      grid_lat_min=65; grid_lat_max=67        #Range of lats to search and form subarrays # for subarray around ILAR
      grid_lon_min=-152; grid_lon_max=-148.5

elif [ $region == "AlSub_sm_E" ]; then
      grid_lat_min=63; grid_lat_max=65        #Range of lats to search and form subarrays # for subarray around ILAR
      grid_lon_min=-147; grid_lon_max=-143

elif [ $region == "AlpArray" ]; then
        grid_range=(`awk '{print $3, $4}' ./good_stations.txt | gmt gmtinfo -C | awk '{printf "%.0f %.0f %.0f %.0f", $1-1, $2+1, $3-1, $4+1}'`)
    	grid_lat_min=${grid_range[0]}; grid_lat_max=${grid_range[1]}        #Range of lats to search and form subarrays
    	grid_lon_min=${grid_range[2]}; grid_lon_max=${grid_range[3]}        #Range of lats to search and form subarrays
    	echo grid_lat $grid_lat_min $grid_lat_max grid_lon $grid_lon_min $grid_lon_max

elif [ $region == "Aus" ]; then
    	grid_lat_min=-45; grid_lat_max=10        #Range of lats to search and form subarrays
    	grid_lon_min=105; grid_lon_max=160    #Range of lons to search and form subarrays

elif [ $region == "US" ]; then
    	grid_lat_min=25; grid_lat_max=50        #Range of lats to search and form subarrays
    	grid_lon_min=-130; grid_lon_max=-60    #Range of lons to search and form subarrays

elif [ $region == "Mex" ]; then
    	grid_lat_min=0; grid_lat_max=34        #Range of lats to search and form subarrays
    	grid_lon_min=-120; grid_lon_max=-60    #Range of lons to search and form subarrays
fi


# grid_inc=2.5# /2 for smllaer/1 for ilar          #used for sub-array Alaska  #Increment for grid spacing (in degrees)
#was 6 for whole grsn
grid_inc=2  #Increment for grid spacing (in degrees)

#===========
#Subarray Options
#===========
number_min=14 #Minimum desired number of stations
number_max=75 #Maximum desired number of stations

gridsize=7 # for grid station arrangement

#When constructing the subarray, use either stations within circular region around the base station, prioritised by closest stations (CIRC), or stations on a regular grid (GRID)
selection_type=CIRC #or CIRC

#Prepare output files
station_list_total=station_list_TOTAL

#5x5 grid
#   __ __  3 __ __
#   __  7  8  9 __
#   11 12 13 14 15
#   __ 17 18 19 __
#   __ __ 23 __ __

#7x7 grid
#   __ __ __ _4 __ __ __
#   __ __ 10 11 12 __ __
#   __ 16 17 18 19 20 __
#   22 23 24 25 26 27 28
#   __ 30 31 32 33 34 __
#   __ __ 38 39 40 __ __
#   __ __ __ 46 __ __ __

#9x9 grid
#  __ __ __ __ _5 __ __ __ __
#  __ __ __ 13 14 15 __ __ __
#  __ __ 21 22 23 24 25 __ __
#  __ 29 30 31 32 33 34 35 __
#  37 38 39 40 41 42 43 44 45
#  __ 47 48 49 50 51 52 53 __
#  __ __ 57 58 59 60 61 __ __
#  __ __ __ 67 68 69 __ __ __
#  __ __ __ __ 77 __ __ __ __


#===========
#Prepare output files
#===========
#IF FIRST RUN THEN CLEAN AND OPEN OUTPUT FILES
firstrun=Y
if [ $firstrun == "Y" ]; then
	if [ -d $beamdir ]; then
		\rm -r $beamdir; mkdir $beamdir
	else
		mkdir $beamdir
	fi

	for phase in ${phase_list[*]}; do
	    \rm -f $work"/TA_SubArray_SmKS_Search_"$eventdate"_"$comproot$comp"_"$phase".dat" $work"/Basestation_Arrays."$eventdate"_"$comproot$comp"_"$phase".dat"
	    touch $work"/TA_SubArray_SmKS_Search_"$eventdate"_"$comproot$comp"_"$phase".dat" $work"/Basestation_Arrays."$eventdate"_"$comproot$comp"_"$phase".dat"
	done
	\rm -f $work"Stations_to_keep."$eventdate"_"$comproot$comp".dat" $work"Stations_to_reject."$eventdate"_"$comproot$comp".dat"
	touch -f $work"Stations_to_keep."$eventdate"_"$comproot$comp".dat" $work"Stations_to_reject."$eventdate"_"$comproot$comp".dat"
	\rm -f ARRAY_ROW; touch ARRAY_ROW
	\rm $station_list_total; touch $station_list_total


#IF NOT FIRST RUN THEN ONLY OPEN OUTPUT FILES
else
	if [ ! -d $beamdir ]; then
		mkdir $beamdir
	fi

	for phase in ${phase_list[*]}; do
	    touch $work"/TA_SubArray_SmKS_Search_"$eventdate"_"$comproot$comp"_"$phase".dat" $work"/Basestation_Arrays."$eventdate"_"$comproot$comp"_"$phase".dat"
	done
	touch -f $work"Stations_to_keep."$eventdate"_"$comproot$comp".dat" $work"Stations_to_reject."$eventdate"_"$comproot$comp".dat"
	touch ARRAY_ROW
	touch $station_list_total

fi
basestation_var=() #Set up empty array to store our basestations in
#------------------
#------------------


#######
#Event location
sacfile_one=`ls *$sacroot | head -n1`
evla=`sachead $sacfile_one EVLA | awk '{printf "%.2f", $2}'`
evlo=`sachead $sacfile_one EVLO | awk '{printf "%.2f", $2}'`
evdep=`sachead $sacfile_one EVDP | awk '{if ($2>700) printf "%.1f", $2/1000; else printf "%.1f", $2}'`
evmag=`echo $event | sed 's/[-A-Za-z]/ /g' | awk '{print $4/10}'`
#######


#######
#Set up station list
#---------
#START IF: FIRST RUN - CREATE STATION LIST
#---------
if [ $firstrun == "Y" ]; then
\rm -f STA_AMP_LIST.txt; touch STA_AMP_LIST.txt
cnt=1
for sacfile in `ls *$sacroot`; do
	       stanm=`sachead $sacfile kstnm | awk '{print $2}'`
	       depmin=`sachead $sacfile depmin | awk '{print $2}'`
	       depmax=`sachead $sacfile depmax | awk '{print $2}'`
	       stala=`sachead $sacfile stla | awk '{print $2}'`
	       stalo=`sachead $sacfile stlo | awk '{print $2}'`
	       stael=`sachead $sacfile stel | awk '{print $2}'`
	       stadp=`sachead $sacfile stdp | awk '{print $2}'`
	       time_beg=`sachead $sacfile B | awk '{print $2}'`
               time_end=`sachead $sacfile E | awk '{print $2}'`
	       length_flag=`echo $time_beg $time_end | awk '{if (($1>2000) || ($2<100)) print "SHT"; else print "LNG"}'`
	       if [ $length_flag == "SHT" ]; then
		       echo $stanm >> stations_to_remove.$eventdate
	       fi
	       echo $cnt : $stanm $depmin $depmax >> STA_AMP_LIST.txt
	       printf "%4s %9.4f %9.4f %7.2f %7.2f %s\n" $stanm $stala $stalo $stael $stadp $sacfile >> $station_list_total
	       echo sacfile $sacfile stala $stala stalo $stalo
((cnt++))
done
pwd



#Check over each trace in file to see if AMP_LIST.txt has amplitude values or not
#This filters out dead traces and removes them from STA_LIST.txt
unset nanvar
med_min=`awk '{printf "%.25f\n", $4}' STA_AMP_LIST.txt | sort -n | awk ' { a[i++]=$1; } END { x=int((i+1)/2); if (x < (i+1)/2) print (a[x-1]+a[x])/2; else print a[x-1]; }' | awk '{printf "%.25f\n", $1*10000}'`
med_max=`awk '{printf "%.25f\n", $5}' STA_AMP_LIST.txt | sort -n | awk ' { a[i++]=$1; } END { x=int((i+1)/2); if (x < (i+1)/2) print (a[x-1]+a[x])/2; else print a[x-1]; }' | awk '{printf "%.25f\n", $1*10000}'`
echo med_min $med_min med_max $med_max
nanvar=(`awk -v med_min=$med_min -v med_max=$med_max '{if ($4=="nan" || $4==0 || $5=="nan" || $5==0 || $4<med_min) print $3}' STA_AMP_LIST.txt`)


echo nanvar ${nanvar[*]}
echo ==
if [ ! -z "${nanvar[*]}" ]; then
echo nanvar contains ${nanvar[*]}

for nansta in ${nanvar[*]}; do
	echo removing sta $nansta
sed -i "/$nansta$/d" STA_AMP_LIST.txt
echo $nansta >> stations_to_remove.$eventdate
done
fi

#Remove predefined "bad" traces from list and don't use

for word in `cat stations_to_remove.$eventdate`; do
sed -i "/$word/d" $station_list_total
done


#-------
#END IF: FIRST RUN - CREATE STATION LIST
#-------
fi
#######
#-----------------




###########################################
###########################################
# START RUNNING
echo "SETUP COMPLETE. START RUNNING"
###########################################
###########################################

echo ---
echo $station_list_total
head $station_list_total

#===========
#LOOP START: LOOP OVER BASE STATION LATITUDE
#===========
for grid_lat in `seq $grid_lat_min $grid_inc $grid_lat_max`; do  #25 50

#===========
#LOOP START: LOOP OVER BASE STATION LONGITUDE
#===========
for grid_lon in `seq $grid_lon_min $grid_inc $grid_lon_max`; do  #-130 -90
echo GRID_LAT $grid_lat GRID_LON $grid_lon

#This skips ahead to a certain array if we gave $1 in STDIN
if [ $grid_num -lt $skippingto ]; then
((grid_num+=1))
echo Array number $grid_num Array too early: skipping to $skippingto
continue
fi
echo grid_num $grid_num


#Find $basestation, which is the seismic station around which we will build our subarray
#Finds stations that are within +/- 0.5 degrees of the grid point, then picks the closest of these to the grid point by geodesic distance
unset basestation
baselim=0.5
awk -v baselim=$baselim '{if ($2>('$grid_lat'-baselim) && $2<=('$grid_lat'+baselim) && $3>('$grid_lon'-baselim) && $3<=('$grid_lon'+baselim)) print '$grid_lat', '$grid_lon', $2, $3}' $station_list_total > base_list_$$
awk -v baselim=$baselim '{if ($2>('$grid_lat'-baselim) && $2<=('$grid_lat'+baselim) && $3>('$grid_lon'-baselim) && $3<=('$grid_lon'+baselim)) print $1}' $station_list_total > base_name_$$
$py3 $pydir"distcalc_geodesic_LIST_SmKS.py" base_list_$$ base_list_out_$$ #Prints out: BaseStaLat BaseStaLon StaLat StaLon Dist Az
basestation=`paste base_list_out_$$ base_name_$$ | sort -n -k5,6 | awk 'NR==1 {print $7}'`
#DEBUG paste base_list_out_$$ base_name_$$ | sort -n -k5,6 | awk 'NR==1 {print $0}'
\rm base_list_$$ base_list_out_$$ base_name_$$


#---------------------------
#START IF: UNSET BASESTATION
#---------------------------
#Check to see if there is a base station to use
if [ ! -z $basestation ]; then
echo BASESTATION SET

#===========================================================
#Function to check if string is in array
containsElement () { for e in "${@:2}"; do [[ "$e" = "$1" ]] && return 0; done; return 1; }
#===========================================================



#-----------------------------------------------------------
#CHECK: Is new basestation already in array of used basestations ($basestation_var)?
containsElement "$basestation" "${basestation_var[@]}"
in_var=$?  #0 if yes (already used), 1 if no (not already used)

if [ $in_var -eq 0 ]; then
echo BASE STATION ALREADY USED
#DEBUG#echo basestation $basestation basestation_var ${basestation_var[*]}
((grid_num+=1))
continue #Skip to next basestation position
elif [ $in_var -eq 1 ]; then
basestation_var=(${basestation_var[*]} $basestation)
fi
#-----------------------------------------------------------


#Set grid to base station location
basestation_LL=(`awk '$1~"'$basestation'" {print $2, $3}' $station_list_total`)
basestation_lat=${basestation_LL[0]}
basestation_lon=${basestation_LL[1]}
echo BASESTATION_LAT: ${basestation_LL[0]} BASESTATION_LON: ${basestation_LL[1]} BASESTATION_NAME $basestation
distbaz_RD=(`$py3 $pydir"distcalc_geodesic_STDIN.py" ${basestation_LL[0]} ${basestation_LL[1]} $evla $evlo | awk '{printf "%.0f %.0f", $1, $2}'`)


#----------------------------------
#Break if distance outside of range
#----------------------------------
if [ ${distbaz_RD[0]} -lt $lim_lower_ALL -o ${distbaz_RD[0]} -gt $lim_upper_ALL ]; then
echo BASESTATION $basestation OUTSIDE OF PP DISTANCE RANGE, ${distbaz_RD[0]} less than $lim_lower_ALL or ${distbaz_RD[0]} greater than $lim_upper_ALL
((grid_num+=1))
continue #Skip to next basestation position
else
echo BASESTATION $basestation WITHIN PP DISTANCE RANGE, ${distbaz_RD[0]} greater than $lim_lower_ALL and ${distbaz_RD[0]} less than $lim_upper_ALL
fi


#----------------------------------------------------------------------
#Construct grid of nearby stations to select the subarray stations from
#----------------------------------------------------------------------
#Calculate how many degrees are in $TAspacingKM at the latitude of the base station
#TAspacingKM=60 #I was using 70 km before, since this is the nominal spacing of the USArray, but I'm trying 60 now
TAspacingKM=60 #I was using 70 km before, since this is the nominal spacing of the USArray, but I'm trying 60 now
lonplus=`echo $basestation_lon | awk '{print $1+1}'` #Longitude plus 1
latplus=`echo $basestation_lat | awk '{print $1+1}'` #Latitude plus 1

#LATITUDE: Earth narrowing (towards poles)
#Measure length one degree of LATITUDE at present position
one_deg_lat=`$py3 $pydir"distcalc_geodesic_STDIN.py" $latplus $basestation_lon $basestation_lat $basestation_lon | awk '{print $1}'` #1 degree of latitude (at present longitude) in degrees
spacing_deg_lat=`echo $one_deg_lat | awk '{print '$TAspacingKM'/(111.12*$1)}'` #Number of degrees in 70 km (rough TA spacing).


#LONGITUDE: Earth narrowing (towards poles)
#Measure length one degree of LONGITUDE at present position
one_deg_lon=`$py3 $pydir"distcalc_geodesic_STDIN.py" $basestation_lat $lonplus $basestation_lat $basestation_lon | awk '{print $1}'` #1 degree of longitude (at present latitude) in degrees
spacing_deg_lon=`echo $one_deg_lon | awk '{print '$TAspacingKM'/(111.12*$1)}'` #Number of degrees in 70 km (rough TA spacing).

#How big an area to search for nearby stations to use for subarray
#half_aperture = Multiplier used when creating grid to fit array to. DEFAULT=2.5 for 5x5 grid
#numsta_var = priority of stations on grid to select to favour constructing a diamond shape with 70 km station spacing
if [ $gridsize -eq 5 ]; then
    half_aperture=2.5; numsta_var=(13 14 12 8 18 7 19 9 17 15 11 3 23 20 6 10 16 4 22 2 24 5 25 1 21)

elif [ $gridsize -eq 7 ]; then
    half_aperture=3.5; numsta_var=(25 26 32 24 18 33 31 17 19 27 39 23 11 34 38 16 12 20 40 30 10 41 37 9 13 28 46 22 4 35 45 15 5 21 47 29 3 42 44 8 6 14 48 36 2 49 43 1 7) #for 7x7 grid

elif [ $gridsize -eq 9 ]; then
    half_aperture=4.5; numsta_var=(41 42 50 40 32 51 49 31 33 52 68 38 24 34 52 58 30 43 59 39 23 51 49 31 33 45 77 37 5 53 67 29 15 35 69 47 13 61 57 21 25 46 76 30 6 36 78 46 4 62 66 20 16 70 56 12 26 71 66 11 17 1 2 3 7 8 9 73 74 75 79 80 81 18 27 63 80 64 55 10 19) #for 9x9 grid
#Alternative 9x9 grid    numsta_var=(41 42 50 40 32 51 49 31 33 43 59 39 23 60 48 22 34 58 30 24 52 61 57 21 25 44 68 38 14 53 67 29 15 35 69 47 13 45 77 37 5 12 16 66 70 20 26 56 62 11 17 65 71 76 30 6 46 78 46 4 36 63 72 75 74 19 10 7 8 18 27 79 80 55 64 2 3  81 73 1 9) #for 9x9 grid
fi


#Create grid of preferred station locations
\rm -f STAT_GRID; touch STAT_GRID
echo 0 | awk '{for (i = ('$basestation_lon'-('$spacing_deg_lon'*'$half_aperture')); i <= ('$basestation_lon'+('$spacing_deg_lon'*'$half_aperture')+0.1); i+='$spacing_deg_lon') for (j = ('$basestation_lat'-('$spacing_deg_lat'*'$half_aperture')); j <= ('$basestation_lat'+('$spacing_deg_lat'*'$half_aperture')+0.1); j+='$spacing_deg_lat') print i, j}' | awk '{print $1, $2, NR}' >> STAT_GRID  #+0.1 added to upper limit to account for rounding problems and ensure a full array.

#----------------------------
#SELECT STATIONS IN SUB ARRAY
#----------------------------
wide_aperture=6 #Wide enough radius to capture enough stations to populate the subarray, but not so many that it takes forever to calculate
#DEBUG echo SELECTION PARAMETERS: spacing_deg_lon $spacing_deg_lon spacing_deg_lat $spacing_deg_lat aperture $wide_aperture half_aper $half_aperture

echo ------
station_list_DIST_IN=station_list_DIST_IN_$$
station_list_DIST_NAME=station_list_DIST_NAME_$$
station_list_DIST_OUT=station_list_DIST_OUT_$$
\rm -f $station_list_DIST_IN $station_list_DIST_OUT

range_lat=(`echo ${basestation_LL[0]} | awk '{print $1-'$wide_aperture', $1+'$wide_aperture'}'`)
range_lon=(`echo ${basestation_LL[1]} | awk '{print $1-'$wide_aperture', $1+'$wide_aperture'}'`)
#DEBUG echo range_lat ${range_lat[0]} ${range_lat[1]} range_lon ${range_lon[0]} ${range_lon[1]}


#Calculate distance to stations within range
awk '{if ($2>='${range_lat[0]}' && $2<='${range_lat[1]}' && $3>='${range_lon[0]}' && $3<='${range_lon[1]}') print '${basestation_LL[0]}', '${basestation_LL[1]}', $2, $3}' $station_list_total > $station_list_DIST_IN #Prints: BaseStation LatLon, OtherStationLatLon
awk '{if ($2>='${range_lat[0]}' && $2<='${range_lat[1]}' && $3>='${range_lon[0]}' && $3<='${range_lon[1]}') print $1, $6}' $station_list_total > $station_list_DIST_NAME #Prints: OtherStationName
$py3 $pydir"distcalc_geodesic_LIST_SmKS.py" $station_list_DIST_IN $station_list_DIST_OUT #Prints out: BaseStaLat BaseStaLon StaLat StaLon Dist Az
echo ---

#Sort nearby stations on increasing DISTANCE from BaseStation
\rm -f TEMP_LIST_STATION_LOCS
paste $station_list_DIST_OUT $station_list_DIST_NAME | sort -n -k5,6 > TEMP_LIST_STATION_LOCS #Prints out: BaseStaLat BaseStaLon StaLat StaLon Dist Az StaName
echo --
\rm -f STATIONS_ON_GRID; touch STATIONS_ON_GRID #Where the preferred station names will be listed
echo ==


#==============
#IF START - CONSTRUCT GRID: USE CIRCULAR AREA AND STATIONS CLOSEST TO CENTRE, OR USE GRID
#==============
# radius change
# for all st in GRSN together, use rad =8
if [ $selection_type == "CIRC" ]; then
    search_radius=2.5 # was 1.25 for AK all
    awk '$5<='$search_radius' {print $7, $8}' TEMP_LIST_STATION_LOCS | awk 'NR<='$number_max'' > STATIONS_TO_SELECT.DAT

elif [ $selection_type == "GRID" ]; then
#===========
#LOOP START: LOOP OVER STATIONS
#===========
#LOOP OVER "STAT GRID" AND FIND BEST FITTING STATIONS (CLOSEST TO GRID POINTS DEFINED IN "STAT GRID")
#FITS TO LOCATIONS IN REGULAR 5*5 STATION GRID FROM (1,1) IN NORTH-WEST CORNER TO (5,5) IN SOUTH-EAST CORNER
#PREFERS STATIONS THAT FIT IN "DIAMOND" SHAPE
for numsta in ${numsta_var[*]}; do


#Location of this station
subgrid_latlon=(`awk 'NR=='$numsta' {print $1, $2}' STAT_GRID`)
subgrid_lat=${subgrid_latlon[1]}
subgrid_lon=${subgrid_latlon[0]}
echo numsta $numsta subgrid_lat $subgrid_lat subgrid_lon $subgrid_lon
#Diff combined (lat+lon), Diff lat, Diff lon, Sta, Sta lat, Sta lon, Distance from basestation

#If any station could fit for that subgrid point
closedist=`echo $spacing_deg_lon | awk '{print $1*2}'`
unset sta_fit
sta_fit=(`awk '$3>('$subgrid_lat'-'$closedist') && $3<=('$subgrid_lat'+'$closedist') && $4>('$subgrid_lon'-'$closedist') && $4<=('$subgrid_lon'+'$closedist')' TEMP_LIST_STATION_LOCS | awk 'NR==1'`)

#Check if any station fits and if not then continue to next position in array
if [ -z $sta_fit ]; then
echo No station for STAT_GRID position: $numsta, continuing
continue
fi

#Add station closest to subgrid point to list
#Overall (lat+lon) misfit from grid, lat misfit, lon misfit, StaName, StaLat, StaLon, Distance from BaseStation
awk '$3>('$subgrid_lat'-'$closedist') && $3<=('$subgrid_lat'+'$closedist') && $4>('$subgrid_lon'-'$closedist') && $4<=('$subgrid_lon'+'$closedist')' TEMP_LIST_STATION_LOCS | awk '{print '$subgrid_lat', '$subgrid_lon', $3, $4}' > base_list_$$
awk '$3>('$subgrid_lat'-'$closedist') && $3<=('$subgrid_lat'+'$closedist') && $4>('$subgrid_lon'-'$closedist') && $4<=('$subgrid_lon'+'$closedist')' TEMP_LIST_STATION_LOCS | awk '{print $7, $8}' > base_name_$$
$py3 $pydir"distcalc_geodesic_LIST_SmKS.py" base_list_$$ base_out_$$ #Prints out: BaseStaLat BaseStaLon StaLat StaLon Dist Az
#paste base_out_$$ base_name_$$ | sort -n -k5,6 | head
paste base_out_$$ base_name_$$ | sort -n -k5,6 | awk 'NR==1 {print $7, $8}' >> STATIONS_ON_GRID
echo Station for STAT_GRID position: $numsta
\rm base_out_$$ base_name_$$
#=========
#LOOP END: LOOP OVER STATIONS
#=========
done

#List of closest stations to each grid point
#Remove duplicates and allow only up to $number_max stations through
awk '!seen[$1]++' STATIONS_ON_GRID | awk 'NR<=('$number_max') {print $1, $2}' > STATIONS_TO_SELECT.DAT
echo ---

#==============
#IF END - CONSTRUCT GRID: USE CIRCULAR AREA AND STATIONS CLOSEST TO CENTRE, OR USE GRID
#==============
fi

#Stations to form sub array
station_count_USED=(`cat STATIONS_TO_SELECT.DAT | wc -l`)
station_row_USED=(`cat STATIONS_TO_SELECT.DAT | tr '\n' ' '`)

#---------
#START IF: ENOUGH STATIONS, THEN RUN
#---------
#Continue to next base station if not enough stations
if [ $station_count_USED -lt $number_min ]; then
echo $number stations required, $station_count_USED stations found
echo NOT ENOUGH STATIONS
((grid_num+=1))
continue

else
echo $number_min stations required, $station_count_USED stations found
echo ENOUGH STATIONS
echo station_count_USED $station_count_USED
echo station_row_USED ${station_row_USED[*]} >> ARRAY_ROW
echo --- STATIONS_TO_SELECT.DAT
cat STATIONS_TO_SELECT.DAT
echo ---


#-----------------------
#FOR TESTING: FOR USE IF YOU WANT TO LOOP OVER FILTER FREQUENCIES AND TIME STEPS
#-----------------------
# for fmin in `echo 0.05 0.075 0.1 0.15`; do
#for delta in `echo 20 40 60 80 100 120 140 160 180 200 250 300`; do

#fmin loop
### check Station file HERE!
#-------------
#Run Vespagram
#-------------


#===========
#LOOP START: LOOP OVER PHASES in "Input_Phase_List_"$$
#===========
while read phase phase_taup lim_lower lim_upper; do


echo distbaz_RD ${distbaz_RD[0]} lim_lower_$phase $lim_lower lim_upper_$phase $lim_upper
if [ ${distbaz_RD[0]} -lt $lim_lower -o ${distbaz_RD[0]} -gt $lim_upper ]; then
echo =============
echo =============
echo NOT RUNNING $phase AT ARRAY $arrnum
echo =============
echo =============

else
echo =============
echo =============
echo RUNNING $phase AT ARRAY $arrnum
echo =============
echo =============
#


master_results_list=$work"/TA_SubArray_SmKS_Search_"$eventdate"_"$comproot$comp"_"$phase".dat"
echo SmKS_Vespapack_2020.sh $fmin $fmax $comp $delta $number_min $eventdate $basestation $basestation_lat $basestation_lon $grid_lat $grid_lon $master_results_list $grid_num $slo_min $slo_inc $slo_max $baz_min $baz_inc $baz_max $phase $phase_taup $DO_CIRC $DO_ELEV $elev_vel $DO_RADPAT
echo RUNNING
SmKS_Vespapack_2020.sh $fmin $fmax $comp $delta $number_min $eventdate $basestation $basestation_lat $basestation_lon $grid_lat $grid_lon $master_results_list $grid_num $slo_min $slo_inc $slo_max $baz_min $baz_inc $baz_max $phase $phase_taup $DO_CIRC $DO_ELEV $elev_vel $DO_RADPAT
#TO REMOVE

fi


#=========
#LOOP END: LOOP OVER PHASES in "Input_Phase_List_"$$
#=========
done < $work"Input_Phase_List_"$$

# exit
#-----------------------
#FOR TESTING: FOR USE IF YOU WANT TO LOOP OVER FILTER FREQUENCIES AND TIME STEPS
#-----------------------
# done
#done


#--------
#REMOVALS
#--------
# mkdir $eventdat
# cp TEMP_LIST_STATION_LOCS STATIONS_TO_SELECT.DAT $station_list_DIST_IN $station_list_DIST_OUT STATIONS_ON_GRID TEMP_LIST_STATION_LOCS STAT_GRID $eventdat/

\rm -f TEMP_LIST_STATION_LOCS STATIONS_TO_SELECT.DAT $station_list_DIST_IN $station_list_DIST_OUT STATIONS_ON_GRID TEMP_LIST_STATION_LOCS STAT_GRID

#-----------------------
#END IF: ENOUGH STATIONS
#-----------------------
fi

#REMOVE WHEN READY


#-------------------------
#END IF: UNSET BASESTATION
#-------------------------
else
echo BASESTATION NOT FOUND
fi

#--------------------------------------------------------
#LOOP OVER GRID OF ARRAY AND SELECT A BASE STATION TO USE: END
#--------------------------------------------------------
((grid_num+=1))
done
done

echo ----------------------------
echo COMPLETED ALL GRID LOCATIONS - TOTALLY FINISHED RUNNING. ENJOY YOUR OUPUTS.
echo ----------------------------
##############################

# bit for all folders in sac_files

# cd ../
# done
##
echo ----------------------------
echo COMPLETED ALL EQs
echo ----------------------------

mv -f *RECORD.jpg xf_beam_record/
#Removals
#\rm $work"Input_Phase_List_"$$



#========
#CONSTRUCT ROUGH PDF OF ALL OUTPUTS
#THRERE IS A BETTER SCRIPT THAT CONSTRUCTS ORDERED PDFS
#outpdf="SmKS_"$eventdate"_ALL.pdf"
#gs -o $outpdf -g6120x7920 -sDEVICE=pdfwrite *RECORD.ps
