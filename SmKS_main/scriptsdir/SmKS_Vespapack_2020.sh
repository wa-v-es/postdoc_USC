#! /bin/bash
#Creates Vespagram for any sac files
#24/3/2021
#Dan A Frost
#UC Berkeley
alias sed='/opt/homebrew/bin/gsed'
shopt -s expand_aliases


#
# Set GMT defaults
#
gmt set GMT_COMPATIBILITY 4
gmt gmtset FONT_TITLE 12
gmt gmtset MAP_TITLE_OFFSET -0.2c
gmt gmtset FONT_ANNOT_PRIMARY 9
gmt gmtset FONT_ANNOT_SECONDARY 9
gmt gmtset FONT_LABEL 9
gmt gmtset MAP_LABEL_OFFSET 0.0c


#DECISIONS
ANS1=Y #Loop over slownesses? (Y/N)
plot_type=REDVEL
phase=${20}; phase_taup=${21}
model=prem

#Fpack options
DO_CIRC=${22}
DO_ELEV=${23}
elev_vel=${24}
DO_RADPAT=${25}
#radpat_updo=${26}
#radpat_updo=1


#DIRECTORIES
#EXPORTED - work=`pwd | sed 's/$/\//g'`
#EXPORTED - temps="/NAS/dfrost/Work/Temps/"
#EXPORTED - beamdir=$work"/Beam_traces/"
#EXPORTED - monitoring="/NAS/dfrost/Work/Pdiff/SmKS_new2019_Monitoring/"
#EXPORTED - py3=/bin/python3; pydir="/NAS/dfrost/Work/Python/"
#EXPORTED - fpack_dir="/NAS/dfrost/Work/Programs/Fpack_F90/"
#EXPORTED - ftrace_dir="/NAS/dfrost/Work/Programs/Ftrace_F90/"

#TEMP FILES
xf_slow_xyz=$temps"TEMP_XF_SLOW_XYZ_$$"
beam_slow_xyz=$temps"TEMP_BEAM_SLOW_XYZ_$$"
xf_baz_xyz=$temps"TEMP_XF_BAZ_XYZ_$$"
beam_baz_xyz=$temps"TEMP_BEAM_BAZ_XYZ_$$"

xf_slow_grid=$temps"TEMP_XF_SLOW_GRID_$$"
beam_slow_grid=$temps"TEMP_BEAM_SLOW_GRID_$$"
xf_baz_grid=$temps"TEMP_XF_BAZ_GRID_$$"
beam_baz_grid=$temps"TEMP_BEAM_BAZ_GRID_$$"


#------
#INPUTS
#------
#PROCESS ID
proc_id=$$


#FREQUENCIES
fmin=${1-1}
fmax=${2-2}

#COMPONENT
comp=$3
if [ $comp == "R" ]; then
    polar=SV
elif [ $comp == "T" ]; then
    polar=SH
elif [ $comp == "Z" ]; then
    polar=P
fi

#DELTA
delta=$4

#NUMBER OF STATIONS TO SELECT
number_min=${5-10}

#EVENT DATE
eventdate=${6-0000}


#Basestation
basestation=$7
basestation_lat=$8
basestation_lon=${9}
grid_lat=${10}
grid_lon=${11}

#OUTPUTS
master_results_list=${12}

#NUMBER OF GRID POINT OF ARRAY (in whole loop)
grid_num=${13}

#VESPAGRAM PARAMETERS
slow_min=${14}; slow_inc=${15}; slow_max=${16}
baz_min=${17}; baz_inc=${18}; baz_max=${19}


#--------------------------------
#CHECK IF ANY VARIABLES ARE UNSET
for var in fmin fmax comp delta number_min eventdate basestation basestation_lat basestation_lon grid_lat grid_lon master_results_list grid_num slow_min slow_inc slow_max baz_min baz_inc baz_max phase phase_taup DO_CIRC DO_ELEV elev_vel DO_RADPAT; do
    if [ -z "${!var}" ] ; then
        echo "------------------------"
	echo "Variable $var is not set"
        echo "------------------------"
	exit
    else
	echo Variable $var ${!var}
    fi
done
#--------------------------------
\rm -f *sac.arr *sac.arr.cut *sac.arr.cut *sac.arr.cut.fil
\rm -f *SAC.arr *SAC.arr.cut *SAC.arr.cut *SAC.arr.cut.fil
\rm -f *SAC.resp.arr *SAC.resp.arr.cut *SAC.resp.arr.cut *SAC.resp.arr.cut.fil


#------------------------
#Get sac data from Q-file
#------------------------
#70 km station spacing
numpole=2; numpass=2

#Number of stations to start with (before any selection based on moveout, just a count of which stations fit the array grid in the outer script, SmKS_TA_Diamondsearch.bsh).
number_start=`awk 'END {print NR}' STATIONS_TO_SELECT.DAT`



#######
sacfile_one=`ls *$sacroot | head -n1`
evdep=`sachead $sacfile_one EVDP | awk '{if ($2>700) printf "%.1f", $2/1000; else printf "%.1f", $2}'`
evla=`sachead $sacfile_one EVLA | awk '{printf "%.2f", $2}'`
evlo=`sachead $sacfile_one EVLO | awk '{printf "%.2f", $2}'`
evmag=`sachead $sacfile_one MAG | awk '{printf "%.1f", $2}'`

year=`sachead $sacfile_one nzyear | awk '{print $2}'`
jday=`sachead $sacfile_one nzjday | awk '{print $2}'`
hour=`sachead $sacfile_one nzhour | awk '{printf "%02d", $2}'`
minute=`sachead $sacfile_one nzmin | awk '{printf "%02d", $2}'`
date=(`$py3 $pydir"jdate.py" $year $jday`)

month=${date[1]}
day=${date[2]}
outstring=$year$month$day"_"$hour$minute
#######
echo evla $evla evlo $evlo evmag $evmag base $basestation_lat $basestation_lon


#SAC-WORK
#1. identifies which traces match the list in STATIONS_TO_SELECT.DAT
#2. selects only traces that match $comp
#3. hilbert transforms and flips to SKS polarity
#4. normalises all to polarity of radiation pattern
#5. prints out GCARC distance of each trace
#6. writes out new file containing traces that will be used
#SAC-WORK

#Process traces ------
sackey=".arr"
cnt=1
sac_var=(); gcarc_var=()
\rm -f STA_DISTANCE_LOC.txt; touch STA_DISTANCE_LOC.txt
while read stanm sacfile; do
#for stanm in `cat STATIONS_TO_SELECT.DAT`; do
    echo ----- stanm $stanm sacfile $sacfile
#    echo sacfile $sacfile
    gcarc=`sachead $sacfile gcarc | awk '{print $2}'`
    azi=`sachead $sacfile az | awk '{print $2}'`
    stla=`sachead $sacfile stla | awk '{print $2}'`
    stlo=`sachead $sacfile stlo | awk '{print $2}'`
    stel=`sachead $sacfile stel | awk '{print $2}'`
    stdp=`sachead $sacfile stdp | awk '{print $2}'`
    sac_var=(${sac_var[*]} $sacfile)
    gcarc_var=(${gcarc_var[*]} $gcarc)
    echo $cnt ":" $stanm $gcarc $azi ":" $stla $stlo $stel $stdp $sacfile >> STA_DISTANCE_LOC.txt
sac<<EOF
r $sacfile
interpolate delta 0.025
write append $sackey
q
EOF
((cnt++))

#Check for broken traces
unset trcamp trcb trce
trcamp=`sachead $sacfile$sackey depmax | awk '{print $2}'`
trcb=`sachead $sacfile$sackey b | awk '{printf "%d", $2}'`
trce=`sachead $sacfile$sackey e | awk '{printf "%d", $2}'`
if [ -z $trcamp -o $trcb -eq $trce ]; then
    #trc_broken=`echo $sacfile | cut -f2 -d"_" | cut -f1 -d"."`
    trc_broken=`echo $sacfile | cut -f3 -d"."`
    echo REMOVING $trc_broken
    echo trc_broken $trc_broken
    sed -i "/$trc_broken/d" STATIONS_TO_SELECT.DAT
    sed -i "/$trc_broken/d" STA_DISTANCE_LOC.txt
    echo $trc_broken >> stations_to_remove.$eventdate
fi
done < STATIONS_TO_SELECT.DAT
echo --
number_used=`awk 'END {print NR}' STATIONS_TO_SELECT.DAT`
cat STATIONS_TO_SELECT.DAT
echo number_used $number_used

sort -nk4 STA_DISTANCE_LOC.txt > STA_DISTANCE_LOC_SORT.txt; mv STA_DISTANCE_LOC_SORT.txt STA_DISTANCE_LOC.txt
#Process traces ------


#==============
#Array location
#Calculate arithmetic mean of station locations
TAlatlon=(`gawk 'BEGIN {A=0; B=0; C=0} {A+=$7; B+=$8; C+=$9; D+=1} END {print A/D, B/D, C/D}' STA_DISTANCE_LOC.txt`)

echo evla $evla evlo $evlo evdep $evdep slat ${TAlatlon[0]} slon ${TAlatlon[1]} selv ${TAlatlon[2]}
#Event-Receiver information
#===================
dist_azi_bazi=(`$py3 $pydir"distcalc_obspy.py" $evla $evlo ${TAlatlon[0]} ${TAlatlon[1]} `)
echo dist_azi_bazi ${dist_azi_bazi[*]}


#DISTANCES
#Minor arc
dist=${dist_azi_bazi[0]}
dist_RD=`echo $dist | awk '{printf "%.1f", $1}'`
#Major arc
dist_major=`echo $dist | awk '{print 360-$1}'`


#AZIMUTHS
#From receiver BACK to source - BACK AZ along MINOR ARC
gcp_bazi=${dist_azi_bazi[2]}
gcp_bazi_RD=`echo $gcp_bazi | awk '{printf "%.1f", $1}'`
gcp_bazi_INT=`echo $gcp_bazi | awk '{printf "%.0f", $1}'`
#====
baz=$gcp_bazi_RD
baz_RD=$gcp_bazi_INT
echo Minor arc
echo baz $baz baz_rd $baz_RD

#MAJOR ARC STUFF
##From receiver FORWARD to source along MAJOR ARC - BACK AZ reverse
#gcp_bazi_REVERSE=`echo $gcp_bazi | awk '{if (($1+180)<180) printf "%.0f", $1+180; else if (($1+180)>=180) printf "%.0f", $1-180}'`
#gcp_bazi_REVERSE_INT=`echo $gcp_bazi_REVERSE | awk '{printf "%.0f", $1}'`
##====
#baz=$gcp_bazi_REVERSE
#baz_RD=$gcp_bazi_REVERSE_INT
#echo Major arc
#echo baz $baz baz_rd $baz_RD
#===================

echo dist $dist
echo evdep $evdep

#=====================
#=====================
#-----------------------
#Predicted phases
#dist_plus=`echo $dist 360 | awk '{printf "%.2f", $1+$2}'`
#taup time -h $evdep -deg $dist_plus -ph P,PP,PPP,PPPP,PPPPP,pP,pPP,pPPP,pPPPP,pPPPPP,Pdiff,SKS,PKS,sSKiKS,sSKIKS,SKIKS,SKiKS,Sdiff,SKKS,SKKKS,SKKKKS,ScS,sScS,S,sS,SS,SSS,SSSS,SSSSS,sSS,sSSS,sSSSS,sSSSSS,sPKS,pPKS,sSKS,sSKKS,sSKKKS,sSKKKKS -mod $model | awk -v dist_plus=$dist_plus '$8==dist_plus' > $temps"PHASE_TIMES_TEMP_$$"
taup time -h $evdep -deg $dist -ph P,PP,PPP,PPPP,PPPPP,pP,pPP,pPPP,pPPPP,pPPPPP,Pdiff,pPdiff,P^410P,P^660P,PKiKP,SKS,PKS,sSKiKS,sSKIKS,SKIKS,SKiKS,Sdiff,SKKS,SKKKS,SKKKKS,ScS,sScS,S,sS,sP,sPdiff,SS,SSS,SSSS,SSSSS,sSS,sSSS,sSSSS,sSSSSS,sPKS,pPKS,sSKS,sSKKS,sSKKKS,sSKKKKS,PcS,pPcS,sPcS -mod $model > $temps"PHASE_TIMES_TEMP_$$"

Pwave=(`awk '/ P / {print $4, $5, "P"}' $temps"PHASE_TIMES_TEMP_$$"`)
PP=(`awk '/ PP / {print $4, $5, "PP"}' $temps"PHASE_TIMES_TEMP_$$"`)
PPP=(`awk '/ PPP / {print $4, $5, "PPP"}' $temps"PHASE_TIMES_TEMP_$$"`)
PPPP=(`awk '/ PPPP / {print $4, $5, "PPPP"}' $temps"PHASE_TIMES_TEMP_$$"`)
PPPPP=(`awk '/ PPPPP / {print $4, $5, "PPPPP"}' $temps"PHASE_TIMES_TEMP_$$"`)
PPPPPP=(`awk '/ PPPPPP / {print $4, $5, "PPPPPP"}' $temps"PHASE_TIMES_TEMP_$$"`)
lpPwave=(`awk '/ pP / {print $4, $5, "pP"}' $temps"PHASE_TIMES_TEMP_$$"`)
lpPP=(`awk '/ pPP / {print $4, $5, "pPP"}' $temps"PHASE_TIMES_TEMP_$$"`)
lpPPP=(`awk '/ pPPP / {print $4, $5, "pPPP"}' $temps"PHASE_TIMES_TEMP_$$"`)
lpPPPP=(`awk '/ pPPPP / {print $4, $5, "pPPPP"}' $temps"PHASE_TIMES_TEMP_$$"`)
lpPPPPP=(`awk '/ pPPPPP / {print $4, $5, "pPPPPP"}' $temps"PHASE_TIMES_TEMP_$$"`)
P410P=(`awk '/ P\^410P / {print $4, $5, "P^410P"}' $temps"PHASE_TIMES_TEMP_$$"`)
P660P=(`awk '/ P\^660P / {print $4, $5, "P^660P"}' $temps"PHASE_TIMES_TEMP_$$"`)
PKiKP=(`awk '/ PKiKP/ {print $4, $5, "PKiKP"}' $temps"PHASE_TIMES_TEMP_$$"`)
if [ -z ${Pwave[0]} ]; then
Pwave=(`awk '/ Pdiff / {print $4, $5, "Pdiff"}' $temps"PHASE_TIMES_TEMP_$$"`)
fi
pPdiff=(`awk '/ pPdiff / {print $4, $5, "pPdiff"}' $temps"PHASE_TIMES_TEMP_$$"`)
sPdiff=(`awk '/ sPdiff / {print $4, $5, "sPdiff"}' $temps"PHASE_TIMES_TEMP_$$"`)
ScS=(`awk '/ ScS/ {print $4, $5, "ScS"}' $temps"PHASE_TIMES_TEMP_$$"`)
Swave=(`awk '/ S / {print $4, $5, "S"}' $temps"PHASE_TIMES_TEMP_$$"`)
SS=(`awk '/ SS / {print $4, $5, "SS"}' $temps"PHASE_TIMES_TEMP_$$"`)
SSS=(`awk '/ SSS / {print $4, $5, "SSS"}' $temps"PHASE_TIMES_TEMP_$$"`)
SSSS=(`awk '/ SSSS / {print $4, $5, "SSSS"}' $temps"PHASE_TIMES_TEMP_$$"`)
SSSSS=(`awk '/ SSSSS / {print $4, $5, "SSSSS"}' $temps"PHASE_TIMES_TEMP_$$"`)
lsSS=(`awk '/ sSS / {print $4, $5, "sSS"}' $temps"PHASE_TIMES_TEMP_$$"`)
lsSSS=(`awk '/ sSSS / {print $4, $5, "sSSS"}' $temps"PHASE_TIMES_TEMP_$$"`)
lsSSSS=(`awk '/ sSSSS / {print $4, $5, "sSSSS"}' $temps"PHASE_TIMES_TEMP_$$"`)
lsSSSSS=(`awk '/ sSSSSS / {print $4, $5, "sSSSSS"}' $temps"PHASE_TIMES_TEMP_$$"`)
SKIKS=(`awk '/ SKIKS/ {print $4, $5, "SKIKS"}' $temps"PHASE_TIMES_TEMP_$$"`)
SKScd=(`awk '/ SKiKS/ {print $4, $5, "SKScd"}' $temps"PHASE_TIMES_TEMP_$$"`)
SKS=(`awk '/ SKS/ {print $4, $5, "SKS"}' $temps"PHASE_TIMES_TEMP_$$"`)
SKKS=(`awk '/ SKKS/ {print $4, $5, "SKKS"; count++; if (count==1) exit}' $temps"PHASE_TIMES_TEMP_$$"`) #MINOR ARC
#MAJOR ARC - SKKS=(`awk '/ SKKS/ {print $4, $5, "SKKS"}' $temps"PHASE_TIMES_TEMP_$$" | tail -n1`)
S3KS=(`awk '/ SKKKS/ {print $4, $5, "S3KS"; count++; if (count==1) exit}' $temps"PHASE_TIMES_TEMP_$$"`)
S4KS=(`awk '/ SKKKKS/ {print $4, $5, "S4KS"; count++; if (count==1) exit}' $temps"PHASE_TIMES_TEMP_$$"`)
Sdiff=(`awk '/ Sdiff/ {print $4, $5, "Sdiff"}' $temps"PHASE_TIMES_TEMP_$$"`)
PKS=(`awk '/ PKS / {print $4, $5, "PKS"}' $temps"PHASE_TIMES_TEMP_$$"`)
sSKIKS=(`awk '/ sSKIKS/ {print $4, $5, "sSKIKS"}' $temps"PHASE_TIMES_TEMP_$$"`)
sSKScd=(`awk '/ sSKiKS/ {print $4, $5, "sSKScd"}' $temps"PHASE_TIMES_TEMP_$$"`)
sSKS=(`awk '/ sSKS/ {print $4, $5, "sSKS"}' $temps"PHASE_TIMES_TEMP_$$"`)
sSKKS=(`awk '/ sSKKS/ {print $4, $5, "sSKKS"; count++; if (count==1) exit}' $temps"PHASE_TIMES_TEMP_$$"`)
sS3KS=(`awk '/ sSKKKS/ {print $4, $5, "sS3KS"; count++; if (count==1) exit}' $temps"PHASE_TIMES_TEMP_$$"`)
sS4KS=(`awk '/ sSKKKKS/ {print $4, $5, "sS4KS"; count++; if (count==1) exit}' $temps"PHASE_TIMES_TEMP_$$"`)
sScS=(`awk '/ sScS/ {print $4, $5, "sScS"}' $temps"PHASE_TIMES_TEMP_$$"`)
sSwave=(`awk '/ sS / {print $4, $5, "sS"}' $temps"PHASE_TIMES_TEMP_$$"`)
sPwave=(`awk '/ sP / {print $4, $5, "sP"}' $temps"PHASE_TIMES_TEMP_$$"`) #added this
lpPKS=(`awk '/ pPKS / {print $4, $5, "pPKS"}' $temps"PHASE_TIMES_TEMP_$$"`)
lsPKS=(`awk '/ sPKS / {print $4, $5, "sPKS"}' $temps"PHASE_TIMES_TEMP_$$"`)
PcS=(`awk '/ PcS / {print $4, $5, "PcS"}' $temps"PHASE_TIMES_TEMP_$$"`)
lpPcS=(`awk '/ pPcS / {print $4, $5, "pPcS"}' $temps"PHASE_TIMES_TEMP_$$"`)
lsPcS=(`awk '/ sPcS / {print $4, $5, "sPcS"}' $temps"PHASE_TIMES_TEMP_$$"`)

#Account for missing phases (because of Source-Receiver distance)
if [ -z ${SKIKS[1]} ]; then
SKIKS=(0 0 SKIKS)
fi

if [ -z ${SKScd[1]} ]; then
SKScd=(0 0 SKScd)
fi

if [ -z ${Sdiff[1]} ]; then
Sdiff=(0 0 Sdiff)
fi

if [ -z ${ScS[1]} ]; then
ScS=(0 0 ScS)
fi

if [ -z ${Swave[1]} ]; then
Swave=(0 0 S)
fi

if [ -z ${PKS[1]} ]; then
PKS=(0 0 PKS)
fi

if [ -z ${PcS[1]} ]; then
PcS=(0 0 PcS)
fi

echo -- PREDICTED PHASES --
echo Pwave ${Pwave[*]}
echo PP ${PP[*]}
echo PPP ${PPP[*]}
echo pP ${lpPwave[*]}
echo lpPP ${pPP[*]}
echo sP ${sPwave[*]}
echo PKiKP ${PKiKP[*]}
echo sPdiff ${sPdiff[*]}


# echo SKScd ${SKScd[*]}
# echo SKS ${SKS[*]}
# echo SKKS ${SKKS[*]}
# echo S3KS ${S3KS[*]}
# echo S4KS ${S4KS[*]}
# echo Sdiff ${Sdiff[*]}
# echo ScS ${ScS[*]}
# echo S ${Swave[*]}

#${P410P[0]} ${P410P[1]} 0 ${P410P[2]}
# ${P660P[0]} ${P660P[1]} 0 ${P660P[2]}
#Print to files for plotting later
cat<<EOF> $temps"phases_direct_plot_"$$
${Pwave[0]} ${Pwave[1]} 0 ${Pwave[2]}
${SS[0]} ${SS[1]} 0 ${SS[2]}
${PP[0]} ${PP[1]} 0 ${PP[2]}
${PPP[0]} ${PPP[1]} 0 ${PPP[2]}
${PKiKP[0]} ${PKiKP[1]} 0 ${PKiKP[2]}
EOF

#Print to files for plotting later
cat<<EOF> $temps"phases_depth_plot_"$$
${lpPwave[0]} ${lpPwave[1]} 0 ${lpPwave[2]}
${sPwave[0]} ${sPwave[1]} 0 ${sPwave[2]}
${lpPP[0]} ${lpPP[1]} 0 ${lpPP[2]}
${lpPPP[0]} ${lpPPP[1]} 0 ${lpPPP[2]}
${sPdiff[0]} ${sPdiff[1]} 0 ${sPdiff[2]}
${pPdiff[0]} ${pPdiff[1]} 0 ${pPdiff[2]}
EOF


#THIS PHASE
if [ $phase == "SKS" ]; then
    phasePRED=(${SKS[*]})
elif [ $phase == "SKKS" ]; then
    phasePRED=(${SKKS[*]})
elif [ $phase == "Sdiff" ]; then
    phasePRED=(${Sdiff[*]})
    slow_min=4.0; slow_max=13.0
elif [ $phase == "ScS" ]; then
    phasePRED=(${ScS[*]})
elif [ $phase == "S" ]; then
    phasePRED=(${Swave[*]})
    slow_min=7.0; slow_max=16.0
elif [ $phase == "PKS" ]; then
    phasePRED=(${PKS[*]})
elif [ $phase == "PcS" ]; then
    phasePRED=(${PcS[*]})
  elif [ $phase == "PP" ]; then
      phasePRED=(${PP[*]})
fi


#Check to ensure that the target phase exists at this subarray (better precision that decision in SmKS_TALooper as this one take into account source depth and actual TauP predictions)
if [ -z ${phasePRED[1]} ]; then
	echo No target phase at this subarray
	echo $phase phasePRED ${phasePRED[*]}
	exit
fi
#-----------------------


#-----------------------------------
#CHECK FOR DEPTH PHASE CONTAMINATION
contamrange=10; contval=NOCONT
cat<<EOF>contam_list_$$
lpPwave
lpPP
sPKS
pPKS
PKiKP
EOF
sed -i "/^$phase/d" contam_list_$$
for phasen in `cat contam_list_$$`; do
echo phasen $phasen
contval=`echo ${phasePRED[0]} ${!phasen[0]} | awk '{if ( sqrt(($1-$2)**2)<='$contamrange' ) print "CONT"; else print "NOCONT"}'`
if [ $contval == "CONT" ]; then
echo ${phase[2]} CONTAMINATED by $phasen
echo $phase ${phase[0]} CONTAMINATED by $phasen ${!phasen[0]}
break
fi
done
\rm -f contam_list_$$
if [ $contval == "NOCONT" ]; then phasen=NONE; fi
#-----------------------------------
echo phase $phase phasepred ${phasePRED[*]}


#--------------------
#Set time window# changed here such that time if P arrival + 50 sec

# if [ -z ${Pwave[0]} ]; then
# cutmin=`echo ${phasePRED[0]} | awk '{print $1-250}'`
# else
cutmin=`echo ${Pwave[0]} | awk '{print $1+10}'`
# fi
# cutmin=`echo ${phasePRED[0]} | awk '{print $1-300}'`
cutmax=`echo ${phasePRED[0]} | awk '{print $1+100}'`

echo -- TIME WINDOW FOR CALCULATION --
echo cutmin $cutmin cutmax $cutmax
#--------------------
#=====================
#=====================


#=================
#Preprocess traces to deal with phase shifts of SmKS

#For SKS/SKScd/SKIKS we do: nothing, keep everything in the phase of SKS
if [ $phase == "SKS" -o $phase == "SKScd" -o $phase == "SKIKS" -o $phase == "Sdiff" ]; then

sac<<EOF
cut $cutmin $cutmax
r *$sackey
rmean
rtrend
taper TYPE HANNING WIDTH 0.1
write append .cut
q
EOF

#For SKKS we do: hilbert transform by pi/2
elif [ $phase == "SKKS" ]; then

sac<<EOF
cut $cutmin $cutmax
r *$sackey
rmean
rtrend
taper TYPE HANNING WIDTH 0.1
hilbert
mul -1
write append .cut
q
EOF

#For S3KS we do: ....
elif [ $phase == "S3KS" ]; then

sac<<EOF
cut $cutmin $cutmax
r *$sackey
rmean
rtrend
taper TYPE HANNING WIDTH 0.1
mul -1
write append .cut
q
EOF

#For S4KS we do: ....
elif [ $phase == "S4KS" -o $phase == "S" ]; then

sac<<EOF
cut $cutmin $cutmax
r *$sackey
rmean
rtrend
taper TYPE HANNING WIDTH 0.1
hilbert
write append .cut
q
EOF

#For other phases we do: ....
else

sac<<EOF
cut $cutmin $cutmax
r *$sackey
rmean
rtrend
taper TYPE HANNING WIDTH 0.1
write append .cut
q
EOF

fi
sackey=".arr.cut"
#=================

#------------------------
#Check polarity of phase
cmtlist=$data_dir"Event_list_CMTndk_1990_2021_M5.0_d0-700.dat"

#Event details
CMT=(`grep $year$month$day$hour$minute $cmtlist | head -n 1 | awk '{print $4, $5, $6}'`) #Strike, dip, rake
if [ -z ${CMT+x} ]; then
    CMT=(0 0 0)
fi
\rm AMP_INFO_$$; touch AMP_INFO_$$
while read cnt dum1 stanm gcarc azi dum2 stla stlo stel stdp sacfile; do
itheta=`taup time -deg $gcarc -mod $model -h $evdep -ph $phase_taup | awk 'NR==6 {print $6}'`
$bin_dir"radiation_thaz"<<EOF > amp_phase
${CMT[0]} ${CMT[1]} ${CMT[2]}
$polar
$itheta $azi
EOF

awk 'NR==1 {print $1}' amp_phase >> AMP_INFO_$$

done < STA_DISTANCE_LOC.txt

ampsum=`awk '{if ($1<0) print -1; else print 1}' AMP_INFO_$$ | awk '{sum+=$1} END {print sum}'`
ampav=`awk '{S+=$1; N+=1} END {printf "%5.2f\n", S/N}' AMP_INFO_$$`
amp_posneg=(`echo $ampsum $number_start | awk '{if ($1==$2) print 1, "SAME"; else if ($1==(-1*$2)) print -1, "SAME"; else if ($1>0) print 1, "DIFF"; else if ($1<0) print -1, "DIFF"}'`) #Checks polarity of phase in traces - normalises amps (1 for positive, -1 for negative) then checks count of this and compares with the number of traces that are used. If all traces have positive/negative amplitudes then $ampsum will be the same as the number of traces, $number_used, with either positive or negative polarities. If $ampsum is not equal to +/- $number_used then there must be a mix of polarities.
#ampav=1; amp_posneg=(1 "SAME")
if [ -z $ampav ]; then
   ampav=1
fi
echo amp_posneg ${amp_posneg[*]} ampav $ampav
\rm -f AMP_INFO_$$
#------------------------


#SAC-WORK
#1. filters a copy of traces that will be used
#2. calculates SNR of each trace for the phase of interest, relative to the time prior to the phase of interest
#SAC-WORK
#------------------
#SNR using ENVELOPE
#------------------
\rm -f SNR_LIST.txt; touch SNR_LIST.txt

#AllPositivePolarity #Flip all polarities to POSITIVE
#AllPositivePolarity #Does:
#AllPositivePolarity # 1. flips sac traces to positive
#AllPositivePolarity # 2. sets amp_posneg to 1 (for use in Fpack and Ftrace)
#AllPositivePolarity
#AllPositivePolarity # \/\/ Modification for PcS (negative appears positive, so flip it all)
#AllPositivePolarity #amp_posneg[0]=`echo ${amp_posneg[0]} | awk '{print $1*-1}'`
#AllPositivePolarity # /\/\ Modification for PcS (negative appears positive, so flip it all)
#AllPositivePolarity
#AllPositivePolarity if [ ${amp_posneg[0]} -eq -1 ]; then
#AllPositivePolarity sac<<EOF
#AllPositivePolarity r *$sackey
#AllPositivePolarity mul -1
#AllPositivePolarity write over
#AllPositivePolarity q
#AllPositivePolarity EOF
#AllPositivePolarity amp_posneg[0]=1
#AllPositivePolarity fi

sac<<EOF
r *$sackey
bp co $fmin $fmax n $numpole p $numpass
write append ".fil"
envelope
q
EOF


noi_wid=20
ph_half_wid=15
for sacfile in `ls *$sackey`; do
    gcarc=`sachead $sacfile gcarc | awk '{print $2}'`
    phtime=`taup time -deg $gcarc -mod $model -h $evdep -ph $phase_taup | awk 'NR==6 {print $4}'`

    sacfile_fil=$sacfile".fil"
    sac2xy $sacfile_fil sacfile.xy
    sig_max=`awk -v phtime=$phtime -v ph_half_wid=$ph_half_wid '$1>(phtime-ph_half_wid) && $1<=(phtime+ph_half_wid) {printf "%.14f\n", sqrt($2**2)}' sacfile.xy | sort -nrk1 | head -n1`
    noi_max=`awk -v phtime=$phtime -v noi_wid=$noi_wid '$1>(phtime-(noi_wid*2)) && $1<=(phtime-noi_wid)' sacfile.xy | awk '{S+=($2**2); N+=1} END {print sqrt(S/N)}'`
    snr_trace=`echo $sig_max $noi_max | awk '{printf "%5.2f", $1/$2}'`


#Normalise trace to max amp in direction of radiation pattern (max +ve if +ve rad pat, and vice versa)
    sac2xy $sacfile sacfile.xy
    sig_minmax=(`awk -v phtime=$phtime -v ph_half_wid=$ph_half_wid '$1>(phtime-ph_half_wid) && $1<=(phtime+ph_half_wid) {printf "%.14f\n", $2}' sacfile.xy | gmt gmtinfo -C | awk -v amp=${amp_posneg[0]} '{if (amp==1) print $2; else print $1}'`)
#Normalisation now handled within F-pack and F-trace, don't normalise input sac traces
#sac<<EOF
#r $sacfile
#write append .norm
#q
#EOF



#DEBUG echo ==================
#DEBUG echo sig_max $sig_max noi_max $noi_max snr_trace $snr_trace
echo sig_max $sig_max noi_max $noi_max snr_trace $snr_trace >> SNR_LIST.txt
#DEBUG echo ==================
done
snr_mean_std=(`awk '{sum += $6; sumsq += ($6)**2} END {printf "%.2f %.2f\n", sum/NR, sqrt((sumsq-sum**2/NR)/(NR-1))}' SNR_LIST.txt`)
snr_min_max=(`awk '{if(min==""){min=max=$6}; if($6>max) {max=$6}; if($6< min) {min=$6}} END {printf "%.2f %.2f", min, max}' SNR_LIST.txt`)
echo snr_mean_std_used ${snr_mean_std[*]}
echo snr_min_max ${snr_min_max[*]}
cat SNR_LIST.txt
\rm -f sacfile.xy *$sackey".fil" SNR_LIST.txt
#===============


#Print out array features: Basestation, Used or Not, Number of good and bad stations, mean SNR and STD
basestation_arrays="Basestation_Arrays."$eventdate"_"$comproot$comp"_"$phase".dat"
#\rm $basestation_arrays; touch $basestation_arrays
if [ $number_used -lt $number_min ]; then
echo "TOO FEW STATIONS AFTER POORLY FITTING STATIONS REMOVED"
#TF=Too few stations
#Prints out: BaseStationName BSLat BSLon Index NumSta before any are removed, NumSta after stations with large moveouts are removed, Mean SNR across array including poor stations, StandardDev SNR AstackErrorMEAN AstackErrorSTD
#Astack* is now defunct
echo  $basestation $basestation_lat $basestation_lon TF $number_start $number_used ${snr_mean_std[0]} ${snr_mean_std[1]}
printf "%5s %9.4f %9.4f %2s %2d %2d %5.2f %5.2f %4d\n" $basestation $basestation_lat $basestation_lon TF $number_start $number_used ${snr_mean_std[0]} ${snr_mean_std[1]} $grid_num >> $basestation_arrays
cp $basestation_arrays $monitoring
exit
else
printf "%5s %9.4f %9.4f %2s %2d %2d %5.2f %5.2f %4d\n" $basestation $basestation_lat $basestation_lon GD $number_start $number_used ${snr_mean_std[0]} ${snr_mean_std[1]} $grid_num >> $basestation_arrays
cp $basestation_arrays $monitoring
fi


#==========
#awk '{print $1}' STATIONS_TO_SELECT.DAT | awk 'NR<=('$number'+5)' > STATIONS_TO_SELECT_SCND.DAT
awk '{print $1}' STATIONS_TO_SELECT.DAT >> Stations_to_keep."$eventdate"_"$comproot$comp".dat
echo 0 >> Stations_to_reject."$eventdate"_"$comproot$comp".dat
#==========


#SAC-WORK
#1. identifies new collection of traces by taking only 15 stations from list in STATIONS_TO_SELECT.DAT
#2. selects only traces that match $comp
#3. removes trend and demeans
#4. hilbert transforms and flips to SKS polarity
#5. resamples to 0.025 s (40 Hz)
#6. normalises all to polarity of radiation pattern
#7. writes out new file containing traces that will be used
#SAC-WORK



#SAC-WORK
#1. writes event details
#2. writes out list of stations
#SAC-WORK
#cat EVENT.STX



#SAC-WORK
#1. filters all
#2. calculates envelop
#3. trims traces
#SAC-WORK


#Removals
\rm -f $xf_slow_xyz $beam_slow_xyz $xf_baz_xyz $beam_baz_xyz $xf_slow_grid $beam_slow_grid $xf_baz_grid $beam_baz_grid
touch $xf_slow_xyz $beam_slow_xyz $xf_baz_xyz $beam_baz_xyz $xf_slow_grid $beam_slow_grid $xf_baz_grid $beam_baz_grid



########################
#CALCULATE FTRACE: START
########################
#Loop over slowness
npol=2
FINALMAXFILE=outfile_$$.xy
OUTFILE_SLOW=outfile_slow_$$.xy
OUTFILE_BAZ=outfile_baz_$$.xy
\rm -f $FINALMAXFILE FTR_INP
#===================
#Prepare Ftrace file
sackey=".arr.cut"
numtraces=`ls *$sackey | awk 'END {print NR}'`
option_var=($DO_CIRC $DO_ELEV $elev_vel $DO_RADPAT ${amp_posneg[0]})
option_str=`echo ${option_var[*]} | sed 's/ /_/g'`
#########################
#########################
#option_var="N N 0 Y 1"
echo NUMTRACES > FTR_INP
echo BAZ >> FTR_INP
echo VELKM >> FTR_INP
echo ${TAlatlon[*]} >> FTR_INP
echo $evla $evlo >> FTR_INP
ls *$sackey >> FTR_INP
echo $delta $fmin $fmax $npol 4.0 >> FTR_INP
echo $FINALMAXFILE >> FTR_INP
echo $cutmin $baz_RD >> FTR_INP
echo ${option_var[*]} >> FTR_INP
#cat FTR_INP
#Prepare Ftrace file
#===================


#####
#CALCULATE BEAM AND FTRACE FOR SIGNALS
#========================
#UPDATE FTRACE INPUT FILE
sed -i "1s/.*/$numtraces/" FTR_INP
sed -i "2s/.*/$baz_min\ $baz_inc\ $baz_max/" FTR_INP
sed -i "3s/.*/$slow_min\ $slow_inc\ $slow_max/" FTR_INP
#UPDATE FTRACE INPUT FILE
#========================

echo -- Input for Fpack --
cat FTR_INP

echo -- Run Fpack --
$fpack_dir"fpack_rnorm_tmin_circ_elv_f90" < FTR_INP
cp FTR_INP FTR_INP_fpack


#PRINT OUT RESULTS TO INDIVIDUAL FILES
#FINALMAXFILE: rel_baz, slow, time, XF, Beam, abs_baz
#FOR BAZ- Remove duplicated Baz and Time
sort -nr -k4 $FINALMAXFILE | awk '!seen[$1$3]++' | awk '{printf "%12.9f %12.9f %14.12f %14.12f\n", $3, $1, $4, $5}' > $OUTFILE_BAZ
#FOR SLOW- Remove duplicated Slow and Time
sort -nr -k4 $FINALMAXFILE | awk '!seen[$2$3]++' | awk '{printf "%12.9f %12.9f %14.12f %14.12f\n", $3, $2, $4, $5}' > $OUTFILE_SLOW




awk '{print $1, $2, $3}' $OUTFILE_SLOW > $xf_slow_xyz
awk '{print $1, $2, $4}' $OUTFILE_SLOW > $beam_slow_xyz
awk '{print $1, $2, $3}' $OUTFILE_BAZ > $xf_baz_xyz
awk '{print $1, $2, $4}' $OUTFILE_BAZ > $beam_baz_xyz

echo -- Output for Fpack \(these should all contain something non-zero\) --
gmt gmtinfo $xf_slow_xyz
gmt gmtinfo $beam_slow_xyz
gmt gmtinfo $FINALMAXFILE
echo --

######################
#CALCULATE FTRACE: END
######################


#PLOT setup
plotcutmin=`echo $cutmin | awk '{print $1+10}'`
plotcutmax=`echo $cutmax | awk '{print $1-10}'`


range_slow="-R"$plotcutmin"/"$plotcutmax"/"$slow_min"/"$slow_max
range_baz="-R"$plotcutmin"/"$plotcutmax"/"$baz_min"/"$baz_max
frame="-JX8.5c/7c"
contcut_xf=40; contcut_beam=150


#--------------------
#MAXIMA IN WHOLE PLOT
#Maximum in whole plot
beam_max_WHOLE=(`awk '$1>='$plotcutmin' && $1<='$plotcutmax'' $beam_slow_xyz | awk 'NR == 1 { max = (sqrt($3**2)); maxline = $0; next; } (sqrt($3**2)) > max { max=(sqrt($3**2)); maxline=$0 }; END { print maxline }'`)
echo ---
#Use time and slowness to identify back-azimuth of maximum Beam
#PRINTS: time, slow, beam, rel_baz
beam_max_WHOLE=(`awk '$3=='${beam_max_WHOLE[0]}' && $2=='${beam_max_WHOLE[1]}'' $FINALMAXFILE | awk '{print $1, $2, $3, $4, sqrt($5**2), $5, $6}' | sort -nrk5 | awk 'NR==1 {printf "%7.2f %4.2f %11.9f %7.2f", $3, $2, $6, $1}'`)
DEBUG echo beam_max_WHOLE ${beam_max_WHOLE[*]}
#DEBUG sort -nr -k4 $FINALMAXFILE | head -n1 | awk '{printf "%12.9f %12.9f %12.9f %14.12f\n", $3, $2, $5, $1}'

#Maximum in whole plot
xy_max_WHOLE=(`awk '$1>='$plotcutmin' && $1<='$plotcutmax'' $xf_slow_xyz | sort -nrk3,4 | head -n1`)
xy_max_WHOLE=(`printf "%7.2f %4.2f %6.2f" ${xy_max_WHOLE[0]} ${xy_max_WHOLE[1]} ${xy_max_WHOLE[2]}`)
DEBUG echo xy_max_WHOLE ${xy_max_WHOLE[*]}

#--------------------


#-----------------------
#Ftrace- phase arrivals
#-----------------------
#phase max - maximum XF within 15 seconds of predicted phase arrival
#max: Time, Slow, Mag

#List of: phase NOCONTt1 NOCONTt2 CONTt1 CONTt2
cat<<EOF> CONT_TIME_LIST_$$
PKS 12 12 10 10
S 12 12 10 10
SKS 12 12 4 6
SKKS 12 12 6 12
S3KS 6 8 4 8
S4KS 6 8 4 8
SKScd 10 10 8 8
SKIKS 10 10 6 6
Sdiff 10 10 8 8
PP 10 10 8 8
EOF

timeranges=(`awk -v phase=$phase '$1==phase {print $2, $3, $4, $5}' CONT_TIME_LIST_$$`)
if [ $contval == "CONT" ]; then
    timerange1=${timeranges[2]}; timerange2=${timeranges[3]}
else
    timerange1=${timeranges[0]}; timerange2=${timeranges[1]}
fi
amp_thres=0.1 #Percentage of max XF at which to pick phase
echo -- Time range for onset selection \(plus, minus relative to TauP prediction \) --
echo timerange $timerange1 timerange $timerange2
slowanom_range=2.5
\rm -f CONT_TIME_LIST_$$

#==================================================================
#==================================================================
#  ONSET PICKING
#==================================================================
#==================================================================
#ONSET PICKING PROCEDURE
#USES SLOWNESS PICKED FROM XF AND TIME PICKED FROM DIFFERENTIATED BEAM
#Find beam max in time range around prediction in XYZ file     - beam_max_xyz_phase_abs
#Find slowness max in time and slowness range around beam max in XYZ file    - xf_max_xyz_phase - (keep this slowness -> OUTPUT)
#Form new beam on maximum XF slowness    - filt_max.xy/xf_max.xy
#Diffentiate filtered beam      - filt_dif_max.xy
#Take absolute beam amplitude in time range around prediction in same direction as radiation pattern   - beam_max_trc_phase_abs
#Calculate absolute diff. beam amplitude (gradient) arriving ('$timerange1'*2) s before beam max, in same direction as radiation pattern   - beamdif_max_trc_phase_pos
#Calculate average noise in diff. trace in window 50-('$timerange1'*2) s before beam max     - beamdif_mean_trc_noi
#Calculate first point at which diff. beam amplitude crosses (diff. beam max - diff. beam noi)*threshold   - beamdif_onset_trc_phase   - (keep this slowness -> OUTPUT)



#-----------------------
#Beam XYZ- phasePRED arrival
#-----------------------
#VARIABLES
# beam_max_xyz_phasePRED_(pos/neg/abs): maximum/minimum/absolute beam amplitude in +/- $timerange around phasePRED-pred
# xf_max_xyz_phasePRED: maximum XF value in +/- $timerange around phasePRED-pred and +/- $slowanom_range around maximum BEAM slowness
echo ----
echo ${phasePRED[0]} ${phasePRED[1]} ${phasePRED[2]} $timerange1 $timerange2 $slowanom_range $beam_slow_xyz $xf_slow_xyz $FINALMAXFILE $proc_id $ampav ${amp_posneg[0]} ${amp_posneg[1]}
echo ----
echo --  Run onset picker - START --
echo SmKS_onset_pick_2020.bsh ${phasePRED[0]} ${phasePRED[1]} ${phasePRED[2]} $timerange1 $timerange2 $slowanom_range $beam_slow_xyz $xf_slow_xyz $FINALMAXFILE $proc_id $ampav ${amp_posneg[0]} ${amp_posneg[1]}
SmKS_onset_pick_2020.bsh ${phasePRED[0]} ${phasePRED[1]} ${phasePRED[2]} $timerange1 $timerange2 $slowanom_range $beam_slow_xyz $xf_slow_xyz $FINALMAXFILE $proc_id $ampav ${amp_posneg[0]} ${amp_posneg[1]}
beam_max_xyz_phase_abs=(`awk 'NR==1' $temps$phase"_PICKS_"$proc_id`)
xf_max_xyz_phase=(`awk 'NR==2' $temps$phase"_PICKS_"$proc_id`)
amplow=(`awk 'NR==3 {print $1}' $temps$phase"_PICKS_"$proc_id`)
amp_posneg=(`awk 'NR==3 {print $2, $3}' $temps$phase"_PICKS_"$proc_id`)
echo --  Run onset picker - END --

# \/ \/ \/ Currently handled in SmKS_onset_picked.bsh
#echo phasePRED ${phasePRED[0]} timerange1 $timerange1 timerange2 $timerange2
#ls $beam_slow_xyz
##Maximum and minimum amplitudes of filtered beam (velocity) around phasePRED-pred
#beam_max_xyz_phase_pos=(`awk '$1>=('${phasePRED[0]}'-'$timerange1') && $1<=('${phasePRED[0]}'+'$timerange2')' $beam_slow_xyz | sort -nrk3,4 | head -n1`)
#beam_max_xyz_phase_neg=(`awk '$1>=('${phasePRED[0]}'-'$timerange1') && $1<=('${phasePRED[0]}'+'$timerange2')' $beam_slow_xyz | sort -nk3,4 | head -n1`)
#
##Range allowed for picks to illustrate on plot
#echo 0 | awk -v time=${phasePRED[0]} -v timerange1=$timerange1 -v timerange2=$timerange2 -v slow=${phasePRED[1]} -v slowrange=$slowanom_range '{print time-timerange1, slow-slowrange"\n"time-timerange1, slow+slowrange"\n"time+timerange2, slow+slowrange"\n"time+timerange2, slow-slowrange"\n"time-timerange1, slow-slowrange}' > $temps"SmKS_slow_pick_range_"$proc_id
#
#
##=====
#amplow=`echo $ampav | awk '{if ((sqrt($1**2))<0.1) print "LOW_AMP"; else print "HIGH_AMP"}'`
#if [ $amplow == "LOW_AMP" ]; then
#amp_posneg=(`echo ${beam_max_xyz_phase_pos[2]} ${beam_max_xyz_phase_neg[2]} | awk '{if ((sqrt($1**2))>(sqrt($2**2))) print 1, "DIFF"; else print -1, "DIFF"}'`)
#fi
##amp_posneg=(1 "SAME")
##=====
#
#echo basestation $basestation
#echo ampsum ${amp_posneg[1]} amp_posneg ${amp_posneg[0]}
#echo beam_max_xyz_phase_pos ${beam_max_xyz_phase_pos[*]} beam_max_xyz_phase_neg ${beam_max_xyz_phase_neg[*]}
#
##Pick maximum/miniumum beam value based on polarity from radiation pattern
#beam_max_xyz_phase_abs=(`echo ${beam_max_xyz_phase_pos[*]} ${beam_max_xyz_phase_neg[*]} | awk '{if ('${amp_posneg[0]}'==1) print $1, $2, $3; else if ('${amp_posneg[0]}'==-1) print $4, $5, $6}'`) #Largest amplitude (pos/neg)
#awk '$1>=('${phasePRED[0]}'-'$timerange1') && $1<=('${phasePRED[0]}'+'$timerange2')' $beam_slow_xyz > $temps"phase_BEAM_TEMP_$$"  #phase beam data around phase-predicted
#awk '$1>=('${phasePRED[0]}'-'$timerange1') && $1<=('${phasePRED[0]}'+'$timerange2')' $xf_slow_xyz > $temps"phase_XF_TEMP_$$" #phase xf data around phase-predicted
#beam_xf_test=(`paste $temps"phase_BEAM_TEMP_$$" $temps"phase_XF_TEMP_$$" | awk '{A+=($1-$4); B+=($2-$5)} END {printf "%.0f %.0f", A*1000, B*1000}'`)
#echo beam_xf_text ${beam_xf_test[*]}
#if [ ${beam_xf_test[0]} -ne 0 -o ${beam_xf_test[1]} -ne 0 ]; then echo NOT EQUAL; exit; fi
#xf_max_xyz_phase=(`paste $temps"phase_BEAM_TEMP_$$" $temps"phase_XF_TEMP_$$" | awk '{if ('${amp_posneg[0]}'>0 && $3>=0 && $2>=('${beam_max_xyz_phase_abs[1]}'-'$slowanom_range') && $2<=('${beam_max_xyz_phase_abs[1]}'+'$slowanom_range')) print $4, $5, $6; else if ('${amp_posneg[0]}'<0 && $3<=0 && $2>=('${beam_max_xyz_phase_abs[1]}'-'$slowanom_range') && $2<=('${beam_max_xyz_phase_abs[1]}'+'$slowanom_range')) print $4, $5, $6}' | sort -nrk3,4 | head -n1`)
#xf_max_xyz_phase=(`printf "%7.2f %4.2f %6.2f" ${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[1]} ${xf_max_xyz_phase[2]}`)
#echo xf_max_xyz_phase ${xf_max_xyz_phase[*]}
#\rm $temps"phase_BEAM_TEMP_$$" $temps"phase_XF_TEMP_$$"
#
##Use time and slowness to identify back-azimuth of maximum XF
##FINALMAXFILE: rel_baz, slow, time, XF, Beam, abs_baz
#xf_max_xyz_phase=(`awk '$3=='${xf_max_xyz_phase[0]}' && $2=='${xf_max_xyz_phase[1]}'' $FINALMAXFILE | sort -nrk4 | awk 'NR==1 {printf "%7.2f %4.2f %7.3f %7.2f %7.2f", $3, $2, $4, $1, $6}'`) #Time, Slow, XF, rel_baz abs_baz
##xf_max_xyz_phase=(1544 6.8 100 0 -55)
##DEBUG echo ===
##DEBUG awk '$3=='${xf_max_xyz_phase[0]}' && $2=='${xf_max_xyz_phase[1]}'' $FINALMAXFILE | sort -nrk4 | head -n20
##DEBUG echo ===
#echo xf_max_xyz_phase ${xf_max_xyz_phase[*]}
#echo ${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[1]}
# /\ /\ /\ Currently handled in SmKS_onset_picked.bsh
\rm -f $FINALMAXFILE
\rm -f $temps"phase_BEAM_TEMP_$$" $temps"phase_XF_TEMP_$$"
#------

#CREATE BEAM AT MAXIMUM SLOWNESS (PICKED FROM F-Trace)
\rm -f FTR_INP
velkm_max=`echo ${xf_max_xyz_phase[1]} | gawk '{if ($1==0) print 111.1/0.01; else printf "%.1f", 111.1/$1}'`
max_baz=${xf_max_xyz_phase[4]}


#########################
#########################
echo $numtraces $max_baz $velkm_max > FTR_INP
echo ${TAlatlon[*]} >> FTR_INP
echo $evla $evlo >> FTR_INP
ls *$sackey >> FTR_INP
echo $delta $fmin $fmax $npol 4.0 >> FTR_INP
echo $cutmin >> FTR_INP
echo ${option_var[*]} >> FTR_INP

echo -- Input for Ftrace --
cat FTR_INP

echo -- Run Ftrace --
$ftrace_dir"ftrace_rnorm_tau_tmin_circ_elv_f90" < FTR_INP

sac<<EOF
r filt.sac
dif
write filt_dif.sac
q
EOF

sac2xy beam.sac beam.xy
sac2xy xf.sac xf.xy
sac2xy filt_dif.sac filt_dif.xy
sac2xy filt.sac filt.xy
#\rm xf.sac filt.sac xp.sac


#Time, Slowness, Amplitude
gawk '{printf "%12.9f %12.9f %14.12f\n",  $1, '${xf_max_xyz_phase[1]}', $2}' beam.xy > beam_max.xy
gawk '{printf "%12.9f %12.9f %14.12f\n",  $1, '${xf_max_xyz_phase[1]}', $2}' filt.xy > filt_max.xy
gawk '{printf "%12.9f %12.9f %14.12f\n",  $1, '${xf_max_xyz_phase[1]}', $2}' xf.xy > xf_max.xy
gawk '{printf "%12.9f %12.9f %14.12f\n", $1, '${xf_max_xyz_phase[1]}', $2}' filt_dif.xy > filt_dif_max.xy


\rm -f $beamdir"BEAM_"$phase"_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base_gridnum"$grid_num"_"$dist_RD"_"$baz"_"*".xy"
\rm -f $beamdir"FILT_"$phase"_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base_gridnum"$grid_num"_"$dist_RD"_"$baz"_"*".xy"
\rm -f $beamdir"XF_"$phase"_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base_gridnum"$grid_num"_"$dist_RD"_"$baz"_"*".xy"
\rm -f $beamdir"FILTDIF_"$phase"_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base_gridnum"$grid_num"_"$dist_RD"_"$baz"_"*".xy"
cp beam_max.xy $beamdir"BEAM_"$phase"_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base_gridnum"$grid_num"_"$dist_RD"_"$baz"_U"${xf_max_xyz_phase[1]}"_B"${xf_max_xyz_phase[4]}"_"${amp_posneg[0]}"amp.xy"
cp filt_max.xy $beamdir"FILT_"$phase"_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base_gridnum"$grid_num"_"$dist_RD"_"$baz"_U"${xf_max_xyz_phase[1]}"_B"${xf_max_xyz_phase[4]}"_"${amp_posneg[0]}"amp.xy"
cp xf_max.xy $beamdir"XF_"$phase"_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base_gridnum"$grid_num"_"$dist_RD"_"$baz"_U"${xf_max_xyz_phase[1]}"_B"${xf_max_xyz_phase[4]}"_"${amp_posneg[0]}"amp.xy"
cp filt_dif_max.xy $beamdir"FILTDIF_"$phase"_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base_gridnum"$grid_num"_"$dist_RD"_"$baz"_U"${xf_max_xyz_phase[1]}"_B"${xf_max_xyz_phase[4]}"_"${amp_posneg[0]}"amp.xy"
#---------------------------

#OUTPUTS
outps=$work"Vespapack_gridnum"$grid_num"_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base_num"$number_used"_"$phase"_"$option_str".ps"
outpsbeam=`echo $outps | sed 's/Vespapack_/VespapackBeam_/'`
outfile_data=$work"Datapack_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base_gridnum"$grid_num"_num"$number_used"_"$phase"_"$option_str".txt"
\rm -f $outps


#=================================================
#PHASE PICKING FROM MAXIMUM BEAM (FORMED ON SLOWNESS OF MAXIMUM IN XF XYZ)
#=================================================
#Pick phase from differentiated beam amplitude (over a threshold)

#VARIABLES
# beam_max_trc_phase_(pos/neg/abs): maximum/minimum/absolute amplitude in filtered beam trace within +/- $timerange of phase-pred
# beam_max_trc_phase_abs_RD = ${amp_posneg[0]}: the direction of the radiation pattern, 1=positive first motion, -1=negative first motion

# beamdif_max_trc_phase_pos/neg: maximum/minimum gradient in ('$timerange1'*2) s before maximum/minimum beam ampltiude
# beamdif_mean_trc_noi: Calculate mean noise in differentiated trace (acceleration) before maximum/minimum beam amplitude (to set baseline)
# beamdif_onset_trc_phase: onset of phase as picked from threshold of maximum/minimum gradient in the $timerange before maximum/minimum gradient



#Maximum and minimum amplitudes of filtered beam (velocity) around phase-pred
beam_max_trc_phase_pos=(`awk -v timerange1=$timerange1 -v timerange2=$timerange2 '$1>=('${phasePRED[0]}'-timerange1) && $1<=('${phasePRED[0]}'+timerange2)' filt_max.xy | sort -nrk3,4 | head -n1`)
beam_max_trc_phase_neg=(`awk -v timerange1=$timerange1 -v timerange2=$timerange2 '$1>=('${phasePRED[0]}'-timerange1) && $1<=('${phasePRED[0]}'+timerange2)' filt_max.xy | sort -nk3,4 | head -n1`)
echo ${beam_max_trc_phase_pos[*]}
echo ${beam_max_trc_phase_neg[*]}

#Pick maximum/miniumum beam value based on polarity from radiation pattern
beam_max_trc_phase_abs=(`echo ${beam_max_trc_phase_pos[*]} ${beam_max_trc_phase_neg[*]} | awk '{if ('${amp_posneg[0]}'==1) print $1, $2, $3; else if ('${amp_posneg[0]}'==-1) print $4, $5, $6}'`) #Largest amplitude (pos/neg)
echo beam_max_abs ${beam_max_trc_phase_abs[*]}
awk -v timerange1=$timerange1 '$1<='${beam_max_trc_phase_abs[0]}' && $1>=('${beam_max_trc_phase_abs[0]}'-( (sqrt(timerange1**2))*3 )) {print $1, $2, $3}' filt_dif_max.xy > filt_dif_max_cut.xy #STANDARD
#MODIFIED awk -v timerange1=$timerange1 '$1<='${beam_max_trc_phase_abs[0]}' && $1>=('${beam_max_trc_phase_abs[0]}'-( (sqrt(timerange1**2))*1 )) {print $1, $2, $3}' filt_dif_max.xy > filt_dif_max_cut.xy

gmt sample1d -Fl -T0.05 filt_dif_max_cut.xy > filt_$$
awk '{print $1, $2, $3}' filt_$$ > filt_dif_max_cut.xy

#From radiation pattern: Positive first motion=1, Negative first motion=-1
beam_max_trc_phase_abs_RD=${amp_posneg[0]}

##Detrend beam_dif, like we used grdtrend in SmKS_onset_picker.bsh
##awk '$1>=('${beam_max_trc_phase_abs[0]}'-5) && $1<='${beam_max_trc_phase_abs[0]}' {print $1, $3}' filt_dif_max.xy > fc.xy
#awk -v timerange1=$timerange1 -v timerange2=$timerange2 '$1>=('${beam_max_trc_phase_abs[0]}'-(timerange1*2)) && $1<=('${beam_max_trc_phase_abs[0]}'+(timerange2*2)) {print $1, $3}' filt_dif_max.xy > fc.xy
#fc_slow=(`awk 'NR==1 {print $2}' filt_dif_max.xy`)
#gmt trend1d fc.xy -Fxr -Np1 > fc_detrend.xy
#awk -v fc_slow=$fc_slow '{print $1, fc_slow, $2}' fc_detrend.xy > filt_dif_max.xy

#Maximum and minimum amplitudes of derivative of beam (acceleration) ('$timerange1'*2) s before the maximum/minimum beam amplitude
beamdif_max_trc_phase_pos=(`awk -v timerange1=$timerange1 '$1>=('${beam_max_trc_phase_abs[0]}'-( (sqrt(timerange1**2))*2)) && $1<='${beam_max_trc_phase_abs[0]}'' filt_dif_max.xy | sort -nrk3,4 | head -n1`)
beamdif_max_trc_phase_neg=(`awk -v timerange1=$timerange1 '$1>=('${beam_max_trc_phase_abs[0]}'-( (sqrt(timerange1**2)) *2)) && $1<='${beam_max_trc_phase_abs[0]}'' filt_dif_max.xy | sort -nk3,4 | head -n1`)


#MAYBE_DONT if [ $beam_max_trc_phase_abs_RD -gt 0 ]; then
#MAYBE_DONT #Calculate mean noise in differentiated trace (acceleration) before maximum/minimum beam amplitude (to set baseline)
#MAYBE_DONT beamdif_mean_trc_noi=`awk '$1>=('${beam_max_trc_phase_pos[0]}'-50) && $1<=('${beam_max_trc_phase_pos[0]}'-('$timerange1'*2)) {A+=$3; B+=1} END {print A/B}' filt_dif_max.xy`
#MAYBE_DONT #Sort backwards in time, then if time is before minimum gradient and greater than time of minimum gradient - $timerange, and if amplitude of gradient is greater than (minimum gradient - average before phase)*threshold then pick time:
#MAYBE_DONT beamdif_onset_trc_phase=(`sort -nrk1 filt_dif_max.xy | awk -v beamdif_mean_trc_noi=$beamdif_mean_trc_noi '$1<='${beamdif_max_trc_phase_pos[0]}' && $1>=('${beamdif_max_trc_phase_pos[0]}'-'$timerange1') && $3<=(('${beamdif_max_trc_phase_pos[2]}'-beamdif_mean_trc_noi)*'$amp_thres') {print $0; count++; if (count==1) exit}'`)
#MAYBE_DONT
#MAYBE_DONT else
#MAYBE_DONT beamdif_mean_trc_noi=`awk '$1>=('${beam_max_trc_phase_neg[0]}'-50) && $1<=('${beam_max_trc_phase_neg[0]}'-('$timerange1'*2)) {A+=$3; B+=1} END {print A/B}' filt_dif_max.xy`
#MAYBE_DONT
#MAYBE_DONT #Sort backwards in time, then if time is before minimum gradient and greater than time of minimum gradient - $timerange, and if amplitude of gradient is greater than (minimum gradient - average before phase)*threshold then pick time:
#MAYBE_DONT beamdif_onset_trc_phase=(`sort -nrk1 filt_dif_max.xy | awk -v beamdif_mean_trc_noi=$beamdif_mean_trc_noi '$1<='${beamdif_max_trc_phase_neg[0]}' && $1>=('${beamdif_max_trc_phase_neg[0]}'-'$timerange1') && $3>=(('${beamdif_max_trc_phase_neg[2]}'-beamdif_mean_trc_noi)*'$amp_thres') {print $0; count++; if (count==1) exit}'`)
#MAYBE_DONT
#MAYBE_DONT fi
#MAYBE_DONT #=================================================
#MAYBE_DONT #=================================================
#MAYBE_DONT
#MAYBE_DONT echo beamdif_onset ${beamdif_onset_trc_phase[*]}
#MAYBE_DONT beamdif_onset_trc_phase=(`printf "%7.2f %4.2f %7.3e" ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} ${beamdif_onset_trc_phase[2]}`) #Time, Slow, Amp

onset_py=(`$py3 $pydir"local_minima_find.py" filt_dif_max_cut.xy`)
beamdif_onset_trc_phase=(`printf "%7.2f %4.2f %7.3e" ${onset_py[0]} ${onset_py[1]} ${onset_py[2]}`) #Time, Slow, Amp
echo Onset time from python code: ${onset_py[*]}
echo Onset time reformatted: ${beamdif_onset_trc_phase[*]}


#--------
#Beam SNR
#--------
SNR_half_width=10
noi_time=15
sig_time_minmax=(`echo ${beamdif_onset_trc_phase[0]} $SNR_half_width | awk '{print $1-$2, $1+$2}'`)
noi_time_minmax=(`echo ${sig_time_minmax[0]} $noi_time | awk '{print $1-($2*2), $1-$2}'`)
echo noi_time_minmax ${noi_time_minmax[0]} ${noi_time_minmax[1]}
#Check if noise window time is outside of trace, if so, then set noise window to start of trace
trace_time_minmax=(`gmt gmtinfo -C filt_max.xy | awk '{print $1+5, $2-5}'`) #Plus/minus 5 to avoid end artefacts
noi_time_minmax=(`echo ${noi_time_minmax[0]} ${trace_time_minmax[0]} ${noi_time_minmax[1]} ${trace_time_minmax[1]} $SNR_half_width | awk '{if ($1<=$2) print $2, $2+$5; else print $1, $3}'`)

echo beamdif_onset_trc_phase ${beamdif_onset_trc_phase[2]}
echo sig_time_minmax ${sig_time_minmax[0]} ${sig_time_minmax[1]}
echo noi_time_minmax ${noi_time_minmax[0]} ${noi_time_minmax[1]}

#-------------
#SNR using MAX
#-------------
#sig_max=`awk '$1>'${sig_time_minmax[0]}' && $1<='${sig_time_minmax[1]}' {printf "%.14f\n", sqrt($3**2)}' filt_max.xy | sort -nrk1 | head -n1`
#noi_max=`awk '$1>'${noi_time_minmax[0]}' && $1<='${noi_time_minmax[1]}' {printf "%.14f\n", sqrt($3**2)}' filt_max.xy | sort -nrk1 | head -n1`
#snr_beam=`echo $sig_max $noi_max | awk '{printf "%7.4f", $1/$2}'`

sig_max=`awk '$1>'${sig_time_minmax[0]}' && $1<='${sig_time_minmax[1]}' {printf "%.14f\n", sqrt($3**2)}' filt_max.xy | sort -nrk1 | head -n1`
noi_max=`awk '$1>'${noi_time_minmax[0]}' && $1<='${noi_time_minmax[1]}'' filt_max.xy | awk '{S+=($3**2); N+=1} END {print sqrt(S/N)}'`
snr_beam=`echo $sig_max $noi_max | awk '{printf "%5.2f", $1/$2}'`
echo ==================
echo sig_max $sig_max noi_max $noi_max snr_beam $snr_beam
echo ==================


##------------------
##SNR using ENVELOPE
##------------------
#sac<<EOF
#r filt.sac
#envelope
#write filt_env.sac
#q
#EOF
#sac2xy filt_env.sac filt_env.xy
#gawk '{printf "%12.9f %12.9f %14.12f\n",  $1, '${xf_max_xyz_phase[1]}', $2}' filt_env.xy > filt_env_max.xy
#sig_max=`awk '$1>'${sig_time_minmax[0]}' && $1<='${sig_time_minmax[1]}' {printf "%.14f\n", sqrt($3**2)}' filt_env_max.xy | sort -nrk1 | head -n1`
#noi_max=`awk '$1>'${noi_time_minmax[0]}' && $1<='${noi_time_minmax[1]}'' filt_env_max.xy | awk '{S+=$3; N+=1} END {print S/N}'`
#snr_beam=`echo $sig_max $noi_max | awk '{printf "%5.2f", $1/$2}'`
#echo ==================
#echo sig_max $sig_max noi_max $noi_max snr_beam $snr_beam
#echo ==================
#--------------------------------------


#-------------------
#Calculate residuals
#Difference between measured XF slowness and predicted slowness (Meas-Pred)
residSLOW=(`echo ${xf_max_xyz_phase[1]} ${phasePRED[1]} | awk '{printf "%4.2f", $1-$2}'`)
#Difference between measured differentiated beam time and predicted time (Meas-Pred)
residTIME=(`echo ${beamdif_onset_trc_phase[0]} ${phasePRED[0]} | awk '{printf "%7.2f", $1-$2}'`)
residBAZ=(`echo ${xf_max_xyz_phase[3]} | awk '{printf "%7.2f", $1}'`)
#-------------------



#---------------------
echo -- Outputs --
echo phase $phase ${xf_max_xyz_phase[*]} time ${phasePRED[0]}
echo Beam max for whole time window: ${beam_max_WHOLE[*]}
echo XF max for whole time window: ${xy_max_WHOLE[*]}

#------------------------
#CREATE GRIDFILES TO PLOT
#------------------------
interp_slow="0.1/0.05"
interp_baz="0.1/0.5"
#Create Beam and XF grids
gmt blockmean $beam_slow_xyz -I$interp_slow $range_slow | gmt surface -G$beam_slow_grid -I$interp_slow $range_slow
gmt blockmean $xf_slow_xyz -I$interp_slow $range_slow | gmt surface -G$xf_slow_grid -I$interp_slow $range_slow

gmt blockmean $beam_baz_xyz -I$interp_baz $range_baz | gmt surface -G$beam_baz_grid -I$interp_baz $range_baz
gmt blockmean $xf_baz_xyz -I$interp_baz $range_baz | gmt surface -G$xf_baz_grid -I$interp_baz $range_baz

#echo --- Beam slow grid
#gmt grdinfo $beam_slow_grid
#echo ---
#gmt grdinfo $xf_slow_grid
#echo ---
#gmt grdinfo $beam_baz_grid
#echo ---
#gmt grdinfo $xf_baz_grid


#Update max from grids
xf_grid_max=`awk -v timerange1=$timerange1 -v timerange2=$timerange2 '$1>=('${phasePRED[0]}'-( (sqrt(timerange1)**2) *1.5)) && $1<=('${phasePRED[0]}'+(timerange2*1.5)) {print $3}' $xf_slow_xyz | gmt gmtinfo -C | awk '{print $2}'`
#ALTERNATE xf_grid_max=`awk -v timerange1=$timerange1 -v timerange2=$timerange2 '$1>=('${beam_max_trc_phase_abs[0]}'-6) && $1<=('${beam_max_trc_phase_abs[0]}'+6) {print $3}' $xf_slow_xyz | gmt gmtinfo -C | awk '{print $2}'`
#xf_grid_max=`gmt grdinfo $xf_slow_grid | gawk '/v_max/ {print $5}'`
xf_grid_inc=`echo $xf_grid_max | gawk '{printf "%.f", $1/10}'`
if [ $xf_grid_inc -eq 0 ]; then
xf_grid_inc=`echo $xf_grid_max | gawk '{print $1/5}'`
fi

beam_grid_max=`gmt grdinfo $beam_slow_grid | gawk '/v_max/ {if ((sqrt($3**2))>$5) print (sqrt($3**2)); else print $5}'`
beam_grid_inc=`echo $beam_grid_max | gawk '{print $1/5}'`


#========================================================
#========================================================
#PLOT
#========================================================
#========================================================

echo ---
echo $xf_grid_max/$xf_grid_inc
echo ----
echo $beam_grid_max / $beam_grid_in

#Create CPTS # if cpt max is > 100, then reclae the max.
xf_grid_max=`echo ${xy_max_WHOLE[2]} | gawk '{printf "%.f", $1}'`
if [ $xf_grid_max -gt 200 ]; then
grid_max_cpt=`echo $xf_grid_max | gawk '{printf "%.f", $1/3}'`
else
grid_max_cpt=`echo $xf_grid_max | gawk '{printf "%.f", $1}'`
fi
echo ----=----
echo grid_max_cpt=$grid_max_cpt
#
beam_max_WHOLE[2]=$(awk -v num="${beam_max_WHOLE[2]}" 'BEGIN { if (num < 0) print -num; else print num }')
###
echo ---
echo after negative correction
echo Beam max for whole time window: ${beam_max_WHOLE[*]}
beam_grid_inc=`echo ${beam_max_WHOLE[2]} | gawk '{print $1/10}'`
# xf_grid_inc=$(echo ${xy_max_WHOLE[2]} | gawk '{print ($1/5) < 0 ? -($1/5) : ($1/5)}')
xf_grid_inc=`echo ${xy_max_WHOLE[2]} | gawk '{print $1/10}'`
##

# grid_max_cpt=`echo $xf_grid_max | gawk '{print $1/2}'`
gmt makecpt -C/Users/keyser/Documents/ScientificColourMaps8/lipari/lipari.cpt --COLOR_FOREGROUND=white -T0/$grid_max_cpt/$xf_grid_inc -I -Z > $temps"TEMP_XF.cpt_$$"
# gmt makecpt -C/Users/keyser/Documents/ScientificColourMaps8/lipari/lipari.cpt --COLOR_FOREGROUND=white -T0/$grid_max_cpt/$xf_grid_inc -I -Z > $temps"TEMP_XF.cpt_$$"
# gmt makecpt -C/Users/keyser/Documents/ScientificColourMaps8/lipari/lipari.cpt --COLOR_FOREGROUND=white -Q -T0/2 -I -Z > $temps"TEMP_XF.cpt_$$"

# gmt makecpt -Cpolar -T-$beam_grid_max/$beam_grid_max/$beam_grid_inc -Z -I > $temps"TEMP_BEAM.cpt_$$"
gmt makecpt -Cpolar -T-${beam_max_WHOLE[2]}/${beam_max_WHOLE[2]}/$beam_grid_inc -Z -I > $temps"TEMP_BEAM.cpt_$$"

scale_var1=8.5c/-0.5c/6c/0.25ch
scale_var2=8.5c/-1.0c/6c/0.25ch
yoffset0=20c
xoffset0=1.5c
xoffset1=10.0c
yoffset1=9.0c
yoffset2=6.75c
yoffset_map="-3c"
time_border=a30f15g30

#Symbols for predicted phases
symb_direct="-Sc0.2c -Gpurple@50 -W0.02c"
symb_depth="-Sc0.2c -Gdarkgreen@50 -W0.02c"
text_direct=" -F+jCM+a90,+f14,0,purple@10"
text_depth=" -F+jCM+a90,+f14,0,darkgreen@10"


#Symbols for picked phases
symb_beam_wholemax="-Sa0.3c -Gwhite@20 -W0.02c"
symb_beam_phasemax="-Sa0.3c -Gblue@20 -W0.02c"
symb_xf_phasemax="-Sa0.3c -Ggreen@20 -W0.02c"
symb_onset="-Sa0.3c -Gred@20 -W0.02c"

#-------------------------------------------------
#BEAM SLOW - START (1)
#------------------------------------------------
gmt grdimage -X$xoffset0 -Y$yoffset0 $beam_slow_grid $range_slow $frame -C$temps"TEMP_BEAM.cpt_$$" -B$time_border/2:"Slowness (s/deg)":Wsen:."Beam - $phase": -K -P > $outps

#BOX box ======
cat >> $outps << EOF
[ /_objdef {ZaDb} /type /dict /OBJ pdfmark
[ {ZaDb} <<
    /Type /Font
    /Subtype /Type1
    /Name /ZaDb
    /BaseFont /ZapfDingbats
>> /PUT pdfmark
[ /_objdef {Helv} /type /dict /OBJ pdfmark
[ {Helv} <<
    /Type /Font
    /Subtype /Type1
    /Name /Helv
    /BaseFont /Helvetica
>> /PUT pdfmark
[ /_objdef {aform} /type /dict /OBJ pdfmark
[ /_objdef {afields} /type /array /OBJ pdfmark
[ {aform} <<
    /Fields {afields}
    /DR << /Font << /ZaDb {ZaDb} /Helv {Helv} >> >>
    /DA (/Helv 0 Tf 0 g)
    /NeedAppearances true
>> /PUT pdfmark
[ {Catalog} << /AcroForm {aform} >> /PUT pdfmark
EOF
#BOX box ======

# gmt grdcontour $beam_slow_grid $range_slow $frame -C$beam_grid_inc -Q$contcut_beam -K -O >> $outps

#Plot predicted phases
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2}' $temps"phases_direct_plot_"$$ | gmt psxy $range_slow $frame $symb_direct -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2}' $temps"phases_depth_plot_"$$ | gmt psxy $range_slow $frame $symb_depth -O -K >> $outps



#Picks:
#Absolute Maximum In Whole Window (blue)
echo ${beam_max_WHOLE[0]} ${beam_max_WHOLE[1]} | gmt psxy $range_slow $frame $symb_beam_wholemax -O -K >> $outps
#phase Beam maximum (blue): max Beam in time window around TauP phase
echo ${beam_max_trc_phase_abs[0]} ${beam_max_trc_phase_abs[1]} | gmt psxy $range_slow $frame $symb_beam_phasemax -O -K >> $outps
#phase XF maximum (green): max XF in time window around TauP phase
echo ${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[1]} | gmt psxy $range_slow $frame $symb_xf_phasemax -O -K >> $outps
#Onset from beam (red) at slowness picked from XF
echo ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} | gmt psxy $range_slow $frame $symb_onset -O -K >> $outps

#Label predicted phases
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2, $4}' $temps"phases_direct_plot_"$$ | gmt pstext $range_slow $frame $text_direct -Xa0.5c -Ya0.5c -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2, $4}' $temps"phases_depth_plot_"$$ | gmt pstext $range_slow $frame $text_depth -Xa0.5c -Ya0.5c -O -K >> $outps

gmt psscale -C$temps"TEMP_BEAM.cpt_$$" -D$scale_var2 -B$beam_grid_inc -O -K >> $outps

#-------------------------------------------------
#BEAM SLOW - END (1) ----------
#-------------------------------------------------


#-------------------------------------------------
# BEAM BAZ - START (2)
#-------------------------------------------------
gmt grdimage $beam_baz_grid $range_baz $frame -C$temps"TEMP_BEAM.cpt_$$" -B$time_border:"Relative back-azimuth (deg)":Wsen:."Beam - $phase": -K -O -X$xoffset1 >> $outps
# gmt grdcontour $beam_baz_grid $range_baz $frame -C$beam_grid_inc -Q$contcut_beam -K -O >> $outps

#Plot predicted phases
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $3}' $temps"phases_direct_plot_"$$ | gmt psxy $range_baz $frame $symb_direct -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $3}' $temps"phases_depth_plot_"$$ | gmt psxy $range_baz $frame $symb_depth -O -K >> $outps


#Picks:
#Absolute Maximum In Whole Window (blue)
echo ${beam_max_WHOLE[0]} ${beam_max_WHOLE[3]} | gmt psxy $range_baz $frame $symb_beam_wholemax -O -K >> $outps
#phase Beam maximum (blue): max Beam in time window around TauP phase
echo ${beam_max_trc_phase_abs[0]} ${xf_max_xyz_phase[3]} | gmt psxy $range_baz $frame $symb_beam_phasemax -O -K >> $outps
#phase XF maximum (green): max XF in time window around TauP phase
echo ${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[3]} | gmt psxy $range_baz $frame $symb_xf_phasemax -O -K >> $outps
#Onset from beam (red) at slowness picked from XF
echo ${beamdif_onset_trc_phase[0]} ${xf_max_xyz_phase[3]} | gmt psxy $range_baz $frame $symb_onset -O -K >> $outps

#Label predicted phases
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $3, $4}' $temps"phases_direct_plot_"$$ | gmt pstext $range_baz $frame $text_direct -Xa0.5c -Ya0.5c -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $3, $4}' $temps"phases_depth_plot_"$$ | gmt pstext $range_baz $frame $text_depth -Xa0.5c -Ya0.5c -O -K >> $outps


#beam_grid_inc=`echo $beam_grid_max | gawk '{print $1/2}'`
#gmt psscale -C$temps"TEMP_BEAM.cpt_$$" -D9c/-0.5c/10c/0.25ch -B$beam_grid_inc -O -K >> $outps
#-------------------------------------------------
#BEAM BAZ - END (2)
#-------------------------------------------------


#-------------------------------------------------
#XF SLOW - START  (3) ----------
#-------------------------------------------------
gmt grdimage $xf_slow_grid $range_slow $frame -C$temps"TEMP_XF.cpt_$$" -B$time_border:"Time (sec)":/2:"Slowness (s/deg)":WSen:."XF - $phase": -O -K -X-$xoffset1 -Y-$yoffset1 >> $outps
# gmt grdcontour $xf_slow_grid $range_slow $frame -W0.02c,blue -C$xf_grid_inc -Q$contcut_xf -K -O >> $outps

#Plot predicted phases
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2}' $temps"phases_direct_plot_"$$ | gmt psxy $range_slow $frame $symb_direct -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2}' $temps"phases_depth_plot_"$$ | gmt psxy $range_slow $frame $symb_depth -O -K >> $outps


#Picks:
#Absolute Maximum In Whole Window (blue)
echo ${beam_max_WHOLE[0]} ${beam_max_WHOLE[1]} | gmt psxy $range_slow $frame $symb_beam_wholemax -O -K >> $outps
#phase Beam maximum (blue): max Beam in time window around TauP phase
echo ${beam_max_trc_phase_abs[0]} ${beam_max_trc_phase_abs[1]} | gmt psxy $range_slow $frame $symb_beam_phasemax -O -K >> $outps
#phase XF maximum (green): max XF in time window around TauP phase
echo ${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[1]} | gmt psxy $range_slow $frame $symb_xf_phasemax -O -K >> $outps
#Onset from beam (red) at slowness picked from XF
echo ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} | gmt psxy $range_slow $frame $symb_onset -O -K >> $outps

#Label predicted phases
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2, $4}' $temps"phases_direct_plot_"$$ | gmt pstext $range_slow $frame $text_direct -Xa0.5c -Ya0.5c -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2, $4}' $temps"phases_depth_plot_"$$ | gmt pstext $range_slow $frame $text_depth -Xa0.5c -Ya0.5c -O -K >> $outps

gmt psscale -C$temps"TEMP_XF.cpt_$$" -D$scale_var2 -B$xf_grid_inc -O -K >> $outps
# gmt psscale -C$temps"TEMP_XF.cpt_$$" -D$scale_var2 -B200 -O -K >> $outps


#PLOT PICK LABELS
range_text="-R0/10/0/10"
echo -0.45 12.25 | gmt psxy $range_text $frame $symb_beam_wholemax -N -O -K >> $outps
echo -0.45 11.75 | gmt psxy $range_text $frame $symb_beam_phasemax -N -O -K >> $outps
echo -0.45 11.25 | gmt psxy $range_text $frame $symb_xf_phasemax -N -O -K >> $outps
echo -0.45 10.75 | gmt psxy $range_text $frame $symb_onset -N -O -K >> $outps
gmt pstext -F+jLM+a0+f10,0,black $frame $range_text -N -O -K <<EOF >> $outps
-0.32 12.25 Max whole window
-0.32 11.75 Beam max
-0.32 11.25 XF max
-0.32 10.75 Beam onset
EOF
#-------------------------------------------------
#XF SLOW - END (3) ----------
#-------------------------------------------------


#-------------------------------------------------
#XF BAZ - START (4) ----------
#-------------------------------------------------
gmt grdimage $xf_baz_grid $range_baz $frame -C$temps"TEMP_XF.cpt_$$" -B$time_border:"Relative back-azimuth (deg)":WSen:."XF - $phase": -O -K -X$xoffset1 >> $outps
# gmt grdcontour $xf_baz_grid $range_baz $frame -W0.02c,blue -C$xf_grid_inc -Q$contcut_xf -K -O >> $outps


#Plot predicted phases
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $3}' $temps"phases_direct_plot_"$$ | gmt psxy $range_baz $frame $symb_direct -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $3}' $temps"phases_depth_plot_"$$ | gmt psxy $range_baz $frame $symb_depth -O -K >> $outps


#Picks:
#Absolute Maximum In Whole Window (blue)
echo ${beam_max_WHOLE[0]} ${beam_max_WHOLE[3]} | gmt psxy $range_baz $frame $symb_beam_wholemax -O -K >> $outps
#phase Beam maximum (blue): max Beam in time window around TauP phase
echo ${beam_max_trc_phase_abs[0]} ${xf_max_xyz_phase[3]} | gmt psxy $range_baz $frame $symb_beam_phasemax -O -K >> $outps
#phase XF maximum (green): max XF in time window around TauP phase
echo ${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[3]} | gmt psxy $range_baz $frame $symb_xf_phasemax -O -K >> $outps
#Onset from beam (red) at slowness picked from XF
echo ${beamdif_onset_trc_phase[0]} ${xf_max_xyz_phase[3]} | gmt psxy $range_baz $frame $symb_onset -O -K >> $outps

#Label predicted phases
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $3, $4}' $temps"phases_direct_plot_"$$ | gmt pstext $range_baz $frame $text_direct -Xa0.5c -Ya0.5c -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $3, $4}' $temps"phases_depth_plot_"$$ | gmt pstext $range_baz $frame $text_depth -Xa0.5c -Ya0.5c -O -K >> $outps
#-------------------------------------------------
#XF BAZ - END (4) ----------
#-------------------------------------------------

frame_text="-JX19c/-5c"
range_text="-R0/10/0/10"
TAll_form=(`printf "%5.2f %6.2f %4.0f" ${TAlatlon[0]} ${TAlatlon[1]} ${TAlatlon[2]}`)
evlld_form=(`printf "%5.2f %6.2f %5.2f" $evla $evlo $evdep`)
gmt pstext $frame_text $range_text -F+jLM+a0+f8,0,black -O -N -Y-$yoffset2 -X-$xoffset1 -K <<EOF >> $outps
-0.5 -1 Event origin: $year $month $day $hour:$minute
-0.5 0 ArrCen la/lo/elv: ${TAll_form[*]} TA ($basestation) (grid $grid_lat, $grid_lon)
-0.5 1 Event la/lo/dp: ${evlld_form[*]}
-0.5 2 Dist: $dist_RD Baz (Arr-Evt): $baz
3.5 1 Time window (after origin): $plotcutmin - $plotcutmax s
3.5 2 Frequencies: $fmin - $fmax Hz  Number of stations: $numtraces
3.5 3 Pred $phase ($model) $comp Comp time/slow: ${phasePRED[0]} ${phasePRED[1]}
3.5 4 XF max time/slow/mag: ${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[1]} ${xf_max_xyz_phase[2]}
3.5 5 Beam onset time/slow/baz/mag: ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]}  ${beam_max_WHOLE[3]} ${beamdif_onset_trc_phase[2]}
3.5 6 Final max time(beam)/slow/baz (XF): ${beamdif_onset_trc_phase[0]} ${xf_max_xyz_phase[1]}  ${xf_max_xyz_phase[3]} Beam SNR $snr_beam
3.5 7 TrcesSNR mn,SD,min,max: ${snr_mean_std[0]} ${snr_mean_std[1]} ${snr_min_max[0]} ${snr_min_max[1]}
EOF
gmt pstext $frame_text $range_text -F+jRT+a0+f9,1,black -O -N -K <<EOF >> $outps
9.5 -1.5 Resid time/slow/baz:
9.5 -0.5 $residTIME s, $residSLOW s/deg $residBAZ deg
EOF

#=======================
#FOR RECORD SECTION PLOT in SmKS_Record_Plot_F90_MAC.bsh
cat <<EOF > $outfile_data
-0.75 -3 10 0 0 LT Origin: $year $month $day $hour:$minute
-0.75 -2 10 0 0 LT ArrCen la/lo/elv: ${TAll_form[*]} Nst:$numtraces
-0.75 -1 10 0 0 LT ArrBaseStn: $basestation, grid la/lp $grid_lat, $grid_lon
-0.75 0 10 0 0 LT Event la/lo/dp: ${evlld_form[*]} Mb:$evmag
-0.75 1 10 0 0 LT Dist: $dist_RD Baz (Arr-Evt): $baz
-0.75 2 10 0 0 LT Frequencies: $fmin - $fmax Hz Delta: $delta
-0.75 3 10 0 1 LT TrcesSNR mn,SD,min,max: ${snr_mean_std[0]} ${snr_mean_std[1]} ${snr_min_max[0]} ${snr_min_max[1]}
-0.75 4 10 0 1 LT Pred $phase ($model) time/U: ${phasePRED[0]} ${phasePRED[1]}
-0.75 5 10 0 1 LT Pick time(beam)/U/Bz (XF): ${beamdif_onset_trc_phase[0]} ${xf_max_xyz_phase[1]}  ${xf_max_xyz_phase[3]}
EOF

cat <<EOF > $temps"SmKS_picks_"$proc_id
${beam_max_WHOLE[0]} ${beam_max_WHOLE[1]}  ${beam_max_WHOLE[3]}
${beam_max_trc_phase_abs[0]} ${beam_max_trc_phase_abs[1]} ${xf_max_xyz_phase[3]}
${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[1]} ${xf_max_xyz_phase[3]}
${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} ${xf_max_xyz_phase[3]}
EOF

cat <<EOF > $temps"SmKS_summary_"$proc_id
11 -0.2 16 0 1 RM Phase: $phase Comp: $comp
11 1.0 14 0 1 RM Gridnum#:$grid_num $basestation
11 2.0 14 0 1 RM BeamDist:$dist_RD
11 3.0 14 0 1 RM Amp: $ampav PN:${amp_posneg[0]} ${amp_posneg[1]}
11 4.0 14 0 1 RM Resid time/slow/baz:
11 5.0 14 0 1 RM $residTIME s, $residSLOW s/dg $residBAZ dg
11 6.0 14 0 1 RM SNR beam: $snr_beam
EOF

if [ $contval == "CONT" ]; then
echo 11 7.0 14 0 1 RM $contval $phasen >> $temps"SmKS_summary_"$proc_id
else
echo 11 7.0 14 0 1 RM $contval >> $temps"SmKS_summary_"$proc_id
fi

#FOR RECORD SECTION PLOT in SmKS_Record_Plot_F90_MAC.bsh
#=======================

if [ $contval == "CONT" ]; then
gmt pstext $frame_text $range_text -O -F+jRM+a0+f14,1,red -N -K <<EOF >> $outps
9.5 0.75 $contval $phasen
EOF
else
gmt pstext $frame_text $range_text -O -F+jRM+a0+f14,1,darkgreen -N -K <<EOF >> $outps
9.5 0.75 $contval
EOF
fi

#Amplitude
gmt pstext $frame_text $range_text -O -F+jLM+a0+f8,1,purple -N -K <<EOF >> $outps
-0.5 -1.4 Amp: $ampav PN: ${amp_posneg[0]}
EOF

#Box box =====
sliceidentifier=$outstring"_"$basestation"_"$basestation_lat"_"$basestation_lon"_"$grid_num"_"$phase
sliceidentifier_rr=$outstring"_"$basestation"_"$basestation_lat"_"$basestation_lon"_"$grid_num"_"$phase"_RERUN"
#sliceidentifier=$outstring"_"$basestation
cat >> $outps << EOF
[
/T (BoxName_1_${outstring}_${basestation}_${grid_num}_${phase})
/FT /Btn
/Rect [7700 1600 8100 2000]
/F 4 /H /O
/BS << /W 1 /S /S >>
/MK << /CA (8) /BC [ 0 ] /BG [ 1 ] >>
/DA (/ZaDb 0 Tf 0 1 0 rg)
/AP << /N << /${sliceidentifier} /null >> >>
/Subtype /Widget
/ANN pdfmark
EOF
#Box box =====

#Box box Rerun =====
cat >> $outps << EOF
[
/T (BoxName_2_${outstring}_${basestation}_${grid_num}_${phase})
/FT /Btn
/Rect [8200 1600 8600 2000]
/F 4 /H /O
/BS << /W 1 /S /S >>
/MK << /CA (8) /BC [ 0 ] /BG [ 1 ] >>
/DA (/ZaDb 0 Tf 0 1 0 rg)
/AP << /N << /${sliceidentifier_rr} /null >> >>
/Subtype /Widget
/ANN pdfmark
EOF
#Box box Rerun =====

##Box box Rerun =====
cat >> $outps <<EOF
[
/Subtype /Widget
/Rect [7700 1200 8600 1550] 		% — position
/T (BoxName_Txt_${outstring}_${basestation}_${grid_num}_${phase})
/FT /Tx
/DA (/Helv 14 Tf 0 0 1 rg) 					% size and color
/V (Text       Notes)
/AA << >>
/ANN pdfmark
EOF
##Box box Rerun =====


#-------------
#Plot stations
#-------------
TAlatlon=(`gawk 'BEGIN {A=0; B=0; C=0} {A+=$7; B+=$8; C+=$9; D+=1} END {print A/D, B/D, C/D}' STA_DISTANCE_LOC.txt`)
map_lat_range=(`echo ${TAlatlon[0]} | awk '{print $1-4, $1+4}'`)
map_lon_range=(`echo ${TAlatlon[1]} | awk '{print $1-4, $1+4}'`)
map_range="-R"${map_lon_range[0]}"/"${map_lon_range[1]}"/"${map_lat_range[0]}"/"${map_lat_range[1]}


map_frame="-JR4.0c"
gmt pscoast -Y$yoffset_map $map_range $map_frame -BWSen -Bxa2f1 -Bya2f1 -W0.01c,darkgreen -Dl -N1/0.03c -Ggray@60 -N2/0.03c,lightgreen -A5000 -O -K >> $outps
awk '{print $2, $3}' station_list_TOTAL | gmt psxy $map_range $map_frame -Si0.2c -W0.02c -: -O -K >> $outps
awk '{print $7, $8, $3}' STA_DISTANCE_LOC.txt | gmt psxy $map_range $map_frame -Si0.2c -Gred -W0.02c -N -: -O -K >> $outps
awk '{print $7-.1, $8, $3}' STA_DISTANCE_LOC.txt | gmt pstext -F+jCM+a0+f4,0,black $map_range $map_frame -: -O -K -N >> $outps
echo ${TAlatlon[0]} ${TAlatlon[1]} | gmt psxy $map_range $map_frame -Si0.2c -Gyellow@20 -W0.02c -: -O -K >> $outps
echo $grid_lon $grid_lat | gmt psxy $map_range $map_frame -Sc0.2c -Gpurple -W0.02c -O -K >> $outps

#----------------
#Plot seismograms
#----------------
sac<<EOF
r *$sackey
bp co $fmin $fmax n $numpole p $numpass
write append ".fil"
q
EOF
sackey=".arr.cut.fil"
stavar=(`awk '{print $3}' STA_DISTANCE_LOC.txt | tr '\n' ' '`)
stavar_uniq=(`awk '{print $3}' STA_DISTANCE_LOC.txt | sort | uniq -u | tr '\n' ' '`)
\rm -f SACFILELIST_SORTED_TEMP; touch SACFILELIST_SORTED_TEMP
while read cnt dum1 stanm gcarc azi dum2 stla stlo stel stdp sacfile; do
sta_tau=(`awk '/'$stanm'/ {print $3, $4}' tau.output`)
echo $sacfile".arr.cut.fil" $gcarc ${sta_tau[1]} $stanm >> SACFILELIST_SORTED_TEMP
done < STA_DISTANCE_LOC.txt



sac_range="-R"$plotcutmin"/"$plotcutmax"/0/"$numtraces
sac_range_text="-R0/10/0/"$numtraces
ampfac=1

dist_minmax=(`awk '{print $4}' STA_DISTANCE_LOC.txt | gmt gmtinfo -C | awk '{print $1-(($2-$1)/10), $2+(($2-$1)/10)}'`)
sac_range="-R"$plotcutmin"/"$plotcutmax"/"${dist_minmax[0]}"/"${dist_minmax[1]}
sac_range_text="-R0/10/"${dist_minmax[0]}"/"${dist_minmax[1]}

sac_range_y=`echo ${dist_minmax[0]} ${dist_minmax[1]} | awk '{print $2-$1}'`
sac_frame_y=4
sac_scale_y=`echo $sac_frame_y | awk '{print 15*(1/$1)}'`
sac_scale_y_dbl=`echo $sac_frame_y | awk '{print 7.5*(1/$1)}'`
sac_frame="-JX10c/"$sac_frame_y"c"


gmt psbasemap $sac_range $sac_frame -B$time_border:"Time after origin (s)":/1:"Distance (deg)":WSen -O -K -X7c >> $outps
#Calculate moveout of phases for plotting
echo DistTABeampoint $dist DistStaMin ${dist_minmax[0]} DistStaMax ${dist_minmax[1]}

#DistTABeampoint DistStaMin phaseslow phasetime
moveout_min=`echo $dist ${dist_minmax[0]} ${beamdif_onset_trc_phase[1]} ${beamdif_onset_trc_phase[0]} | awk '{print $4-(($1-$2)*$3)}'` #Time of phase at this Slowness and Distance
#DistStaMax DistTABeampoint phaseslow phasetime
moveout_max=`echo ${dist_minmax[1]} $dist ${beamdif_onset_trc_phase[1]} ${beamdif_onset_trc_phase[0]} | awk '{print (($1-$2)*$3)+$4}'` #Time of phase at this Slowness and Distance

moveout_min_PRED=`echo $dist ${dist_minmax[0]} ${phasePRED[1]} ${phasePRED[0]} | awk '{print $4-(($1-$2)*$3)}'` #Time of phase at this Slowness and Distance
#DistStaMax DistTABeampoint phaseslow phasetime
moveout_max_PRED=`echo ${dist_minmax[1]} $dist ${phasePRED[1]} ${phasePRED[0]} | awk '{print (($1-$2)*$3)+$4}'` #Time of phase at this Slowness and Distance

#-----
#Plot moveout of picked phase (time and slow) and predicted phase
echo moveout_min $moveout_min moveout_max $moveout_max
if [ $plot_type == "REDVEL" ]; then
echo -e ${beamdif_onset_trc_phase[0]} ${dist_minmax[0]}"\n"${beamdif_onset_trc_phase[0]} ${dist_minmax[1]} | gmt psxy $sac_range $sac_frame -W0.025c,red -O -K >> $outps
echo -e ${phasePRED[0]} ${dist_minmax[0]}"\n"${phasePRED[0]} ${dist_minmax[1]} | gmt psxy $sac_range $sac_frame -W0.025c,purple,"-" -O -K >> $outps
else
echo -e $moveout_min ${dist_minmax[0]}"\n"$moveout_max ${dist_minmax[1]} | gmt psxy $sac_range $sac_frame -W0.05c,red -O -K >> $outps
echo -e $moveout_min_PRED ${dist_minmax[0]}"\n"$moveout_max_PRED ${dist_minmax[1]} | gmt psxy $sac_range $sac_frame -W0.025c,purple,"-" -O -K >> $outps
fi
awk -v dist=$dist 'NR==3 {print $1, dist}' $temps"SmKS_picks_"$proc_id | gmt psxy $sac_range $sac_frame -Sy3.0c -W0.02c,green -O -K >> $outps
#Plot moveout of picked phase (time and slow) and predicted phase
#-----

cnt=0
while read sactrace distance shift stanm; do
ypos=`echo $cnt 0.5 | awk '{print $1+$2}'` #Y-position to plot sac trace
xpos=`echo $cnt 10.25 | awk '{print ($1/10)+$2}'` #X-position to plot sac label

sac2xy $sactrace sac.xy
max=`gmt gmtinfo -C sac.xy | awk '{if (($3*$3)>($4*$4)) print $3*-1; else if (($3*$3)<($4*$4)) print $4}'`
#DEBUG sachead $sactrace depmax
#DEBUG echo sactrace $sactrace distance $distance max $max
trcmax=`awk '{print $2/('$ampfac')}' sac.xy | gmt gmtinfo -C | awk '{if (($1**2)>($2**2)) print sqrt($1**2); else print sqrt($2**2)}'`

if [ $plot_type == "REDVEL" ]; then
    echo shift $shift min $plotcutmin distance $distance
awk -v shift=$shift '{print ($1)-shift, '$distance', $2/('$trcmax')}' sac.xy | gmt pswiggle $sac_range $sac_frame -Z$sac_scale_y -W0.01c -O -K >> $outps
else
    awk '{print $1, '$distance', $2/('$trcmax')}' sac.xy | gmt pswiggle $sac_range $sac_frame -Z$sac_scale_y -W0.01c -O -K >> $outps
fi
echo 10.25 $distance $stanm | gmt pstext -F+jLM+a0+f5,0,black $sac_range_text $sac_frame -N -O -K >> $outps

\rm -f sac.xy

((cnt++))
done < SACFILELIST_SORTED_TEMP

#Plot filtered beam trace
filttime_minmax=(`gmt gmtinfo -C filt_max.xy | awk '{print $1, $2}'`)
vmax=`awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<=(tmax-10)' filt_max.xy | gmt gmtinfo -C | awk '{if (($5*$5)>($6*$6)) print $5*-1; else if (($5*$5)<($6*$6)) print $6}'`
awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<(tmax-10) {print $1, '$dist', ($3/'$vmax')}' filt_max.xy | gmt pswiggle $sac_range $sac_frame -Z$sac_scale_y_dbl -W0.02c,cadetblue -O -K >> $outps
echo 10.75 $dist BEAM | gmt pstext -F+jLM+a0+f7,1,cadetblue $sac_range_text $sac_frame -N -O -K >> $outps


#Plot XF
dist_offset_plot=.1
filttime_minmax=(`gmt gmtinfo -C xf_max.xy | awk '{print $1, $2}'`)
echo Plotting XF max wiggle $filttime_minmax
vmax=`awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<=(tmax-10)' xf_max.xy | gmt gmtinfo -C | awk '{if (($5*$5)>($6*$6)) print $5*-1; else if (($5*$5)<($6*$6)) print $6}'`
#awk '{print $1, '$dist', (($3/'$vmax')/'$ampfac')}' filt_max.xy | gmt pswiggle $sac_range $sac_frame -Z1 -W0.06c,blue -O -K >> $outps
awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<(tmax-10) {print $1, '$dist', ($3/'$vmax')}' xf_max.xy | gmt gmtinfo -C
awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<(tmax-10) {print $1, '$dist'+.2, ($3/'$vmax')}' xf_max.xy | gmt pswiggle $sac_range $sac_frame -Z$sac_scale_y_dbl -W0.01c,darkgreen -O -K >> $outps
echo 10.75 $dist FTRACE | awk '{print $1, $2+.2, $3}' | gmt pstext $sac_range_text $sac_frame -F+jLM+a0+f6,1,darkgreen -N -O -K >> $outps


vmax=`awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<=(tmax-10)' filt_dif_max.xy | gmt gmtinfo -C | awk '{if (($5*$5)>($6*$6)) print $5*-1; else if (($5*$5)<($6*$6)) print $6}'`
awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<(tmax-10) {print $1, '$dist'-.2, ($3/'$vmax')}' filt_dif_max.xy | gmt pswiggle $sac_range $sac_frame -Z$sac_scale_y_dbl -W0.025c,purple -O -K >> $outps
echo 10.75 $dist BEAMDIF | awk '{print $1, $2-.2, $3}' | gmt pstext $sac_range_text $sac_frame -F+jLM+a0+f6,1,purple -N -O -K >> $outps


#echo 10.25 $dist 12 0 1 LM BEAM | gmt pstext $sac_range_text $sac_frame -F+fblue -N -O -K >> $outps
#Plot XF


#If amp is low, then mark with red circle
if [ $amplow == "LOW_AMP" ]; then
echo 9.75 $dist | gmt psxy $sac_range_text $sac_frame -Sc0.4c -Gred -O -K >> $outps
fi

gmt psbasemap $sac_range $sac_frame -B -O >> $outps
#-----------D


SmKS_Record_Plot_2020.sh $plotcutmin $plotcutmax $numtraces $sackey ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} $phase ${phasePRED[0]} ${phasePRED[1]} $dist $outps $grid_num $basestation $proc_id $amplow $xf_grid_max $grid_lat $grid_lon
echo SmKS_Record_Plot_2020.sh $plotcutmin $plotcutmax $numtraces $sackey ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} $phase ${phasePRED[0]} ${phasePRED[1]} $dist $outps $grid_num $basestation $proc_id $amplow $xf_grid_max $grid_lat $grid_lon

SmKS_BeamRecord_Plot_2020.sh $plotcutmin $plotcutmax $numtraces $sackey ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} $phase ${phasePRED[0]} ${phasePRED[1]} $dist $outps $grid_num $basestation $proc_id $amplow $xf_grid_max $grid_lat $grid_lon
echo SmKS_BeamRecord_Plot_2020.sh $plotcutmin $plotcutmax $numtraces $sackey ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} $phase ${phasePRED[0]} ${phasePRED[1]} $dist $outps $grid_num $basestation $proc_id $amplow $xf_grid_max $grid_lat $grid_lon


#echo ${beamdif_onset_trc_phase[0]} ${xf_max_xyz_phase[1]}
#WRITE OUT RESULTS
echo ==
echo $grid_num : ${TAlatlon[0]} ${TAlatlon[1]} ${TAlatlon[2]} : $basestation_lat $basestation_lon $basestation grid $grid_lat $grid_lon dist: $dist baz: $baz resid${phase}\(T/U/B\) $residTIME $residSLOW $residBAZ pred${phase}\(T/U\) ${phasePRED[0]} ${phasePRED[1]} meas${phase}Beam\(T/U/AMP\) ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} ${beam_max_xyz_phase_abs[2]} meas${phase}xf\(T/U/F/rB/aB\) ${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[1]} ${xf_max_xyz_phase[2]} ${xf_max_xyz_phase[3]} ${xf_max_xyz_phase[4]} fmin $fmin fmax $fmax SNRbeam $snr_beam SNRmean ${snr_mean_std[0]} SNRstdev ${snr_mean_std[1]} SNRminmax ${snr_min_max[0]} ${snr_min_max[1]} amp: $ampav ${amp_posneg[0]} ${amp_posneg[1]}: $contval $phasen stanum $numtraces
echo ==
printf "%3d %s %9.4f %9.4f %7.2f %s %9.4f %9.4f %5s %s %9.4f %9.4f %s %9.4f %9.4f %6.1f %3.1f %s %7.2f %s %7.2f %s %7.2f %4.2f %5.2f %s %6.2f %4.2f %s %6.2f %4.2f %5.3f %s %6.2f %4.2f %6.2f %4.2f %4.2f %s %4.2f %s %4.2f %s %5.2f %s %5.2f %s %5.2f %s %5.2f %5.2f %s %4.1f %1d %4s %1s %4s %6s %s %2i\n" $grid_num : ${TAlatlon[0]} ${TAlatlon[1]} ${TAlatlon[2]} : $basestation_lat $basestation_lon $basestation grid: $grid_lat $grid_lon ev: $evla $evlo $evdep $evmag dist: $dist baz: $baz resid${phase}\(T/U/B\) $residTIME $residSLOW $residBAZ pred${phase}\(T/U\) ${phasePRED[0]} ${phasePRED[1]} meas${phase}Beam\(T/U/AMP\) ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} ${beam_max_xyz_phase_abs[2]} meas${phase}xf\(T/U/F/rB/aB\) ${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[1]} ${xf_max_xyz_phase[2]} ${xf_max_xyz_phase[3]} ${xf_max_xyz_phase[4]} fmin $fmin fmax $fmax SNRbeam $snr_beam SNRmean ${snr_mean_std[0]} SNRstdev ${snr_mean_std[1]} SNRminmax ${snr_min_max[0]} ${snr_min_max[1]} amp: $ampav ${amp_posneg[0]} ${amp_posneg[1]} : $contval $phasen stanum $numtraces > T1

if [ -z $stavar_uniq ]; then
echo sta ${stavar[*]} > T2
else
echo sta ${stavar[*]} notused $stavar_uniq > T2
fi

#Paste out to overall results list
paste T1 T2 >> $master_results_list
cp $master_results_list $monitoring

#DISPLAY RESULTS TO SCREEN
echo -- OUTPUT --
printf "%3d %s %9.4f %9.4f %7.2f %s %9.4f %9.4f %5s %s %9.4f %9.4f %s %9.4f %9.4f %6.1f %3.1f %s %7.2f %s %7.2f %s %7.2f %4.2f %5.2f %s %6.2f %4.2f %s %6.2f %4.2f %5.3f %s %6.2f %4.2f %6.2f %4.2f %4.2f %s %4.2f %s %4.2f %s %5.2f %s %5.2f %s %5.2f %s %5.2f %5.2f %s %4.1f %1d %4s %1s %4s %6s %s %2i\n" $grid_num : ${TAlatlon[0]} ${TAlatlon[1]} ${TAlatlon[2]} : $basestation_lat $basestation_lon $basestation grid: $grid_lat $grid_lon ev: $evla $evlo $evdep $evmag dist: $dist baz: $baz resid${phase}\(T/U/B\) $residTIME $residSLOW $residBAZ pred${phase}\(T/U\) ${phasePRED[0]} ${phasePRED[1]} meas${phase}Beam\(T/U/AMP\) ${beamdif_onset_trc_phase[0]} ${beamdif_onset_trc_phase[1]} ${beam_max_xyz_phase_abs[2]} meas${phase}xf\(T/U/F/rB/aB\) ${xf_max_xyz_phase[0]} ${xf_max_xyz_phase[1]} ${xf_max_xyz_phase[2]} ${xf_max_xyz_phase[3]} ${xf_max_xyz_phase[4]} fmin $fmin fmax $fmax SNRbeam $snr_beam SNRmean ${snr_mean_std[0]} SNRstdev ${snr_mean_std[1]} SNRminmax ${snr_min_max[0]} ${snr_min_max[1]} amp: $ampav ${amp_posneg[0]} ${amp_posneg[1]} : $contval $phasen stanum $numtraces




#gv $outps &
gmt ps2raster -A -Tj -E720 -P -Z -Vq *.ps
echo $outps


#Removals
#cp $xf_slow_xyz TEMP_XYZ "$eventdate" $fmin $fmax
#
# mv $xf_slow_xyz grid_folder/xf_slow_xyz"_"$eventdate"_"$fmin"_"$fmax.xyz
# mv $beam_slow_xyz grid_folder/beam_slow_xyz"_"$eventdate"_"$fmin"_"$fmax.xyz
# mv $xf_baz_xyz grid_folder/xf_baz_xyz"_"$eventdate"_"$fmin"_"$fmax.xyz
# mv $beam_baz_xyz grid_folder/beam_baz_xyz"_"$eventdate"_"$fmin"_"$fmax.xyz

mv $xf_slow_grid grid_folder/xf_slow_grid"_"$grid_num"_"$eventdate"_"$fmin"_"$fmax.grd
mv $beam_slow_grid grid_folder/beam_slow_grid"_"$grid_num"_"$eventdate"_"$fmin"_"$fmax.grd
mv $xf_baz_grid grid_folder/xf_baz_grid"_"$grid_num"_"$eventdate"_"$fmin"_"$fmax.grd
mv $beam_baz_grid grid_folder/beam_baz_grid"_"$grid_num"_"$eventdate"_"$fmin"_"$fmax.grd

mv STA_DISTANCE_LOC.txt st_files/STA_DISTANCE_LOC_gridnumber"$grid_num".txt
mv $outfile_data data_pack/"Datapack_gridnum"$grid_num"_"$outstring"_"$fmin"_"$fmax"Hz_"$delta"samps_"$comp"comp_"$basestation"base"_num"$number_used"_"$phase"_"$option_str".txt

\rm -f $xf_slow_xyz $beam_slow_xyz $xf_baz_xyz $beam_baz_xyz $xf_slow_grid $beam_slow_grid $xf_baz_grid $beam_baz_grid $temps"TEMP_XF.cpt_$$" $temps"TEMP_BEAM.cpt_$$" $temps"PHASE_TIMES_TEMP_$$" $temps"STAT_LIST_ALL_TEMP_$$" $temps"phases_depth_plot_"$$ $temps"SmKS_slow_pick_range_"$$ $temps"SmKS_baz_pick_range_"$$
\rm -f filt.xy filt_dif.xy filt_dif_max.xy filt_dif_max_cut.xy filt_max.xy beam_max.xy xf_max.xy beam.sac beam.xy beamfilt.sac filt_dif.sac filt.sac semb.sac xf.sac xf.xy xp.sac COMPTEMP.STX filt_env_max.xy filt_env.xy filt_env.sac filt_$$
\rm -f filt_dif_max.xy filt_max.xy filt.xy filt_dif.xy filt_dif_max_cut.xy
\rm -f $OUTFILE_SLOW $OUTFILE_BAZ T1 T2
\rm -f tau.output  QSTA_AMP_LIST.txt SACFILELIST_SORTED_TEMP # STA_DISTANCE_LOC.txt
\rm -f *sac.arr *sac.arr.cut *sac.arr.cut *sac.arr.cut.fil
\rm -f *SAC.arr *SAC.arr.cut *SAC.arr.cut *SAC.arr.cut.fil
\rm -f *SAC.resp.arr *SAC.resp.arr.cut *SAC.resp.arr.cut *SAC.resp.arr.cut.fil
\rm FTR_INP_fpack FTR_INP  *sac.arr *sac.arr.cut *sac.arr.cut  *sac.arr.cut.fil
