#! /bin/bash
#Plots Vesppack...ps output in a way that emphasises the F-vespa and the record section
#Dan A Frost
#21.3.2021
#UC Berkeley
alias sed='/opt/homebrew/bin/gsed'
shopt -s expand_aliases


#
# Set GMT defaults
#
gmt gmtset FONT_TITLE 12
gmt gmtset MAP_TITLE_OFFSET -0.2c
gmt gmtset FONT_ANNOT_PRIMARY 12
gmt gmtset FONT_ANNOT_SECONDARY 12
gmt gmtset FONT_LABEL 12
gmt gmtset MAP_LABEL_OFFSET 0.0c



echo ===========================
echo ===========================
echo RECORD START
echo ===========================
echo ===========================

#Reads in
plotcutmin=$1
plotcutmax=$2
numtraces=$3
sackey=$4
beamdif_onset_trc_SmKS[0]=$5
beamdif_onset_trc_SmKS[1]=$6
SmKS_phase=$7
SmKS[0]=$8
SmKS[1]=$9
dist=${10}; dist_RD=`echo $dist | awk '{printf "%.1f", $1}'`
outps=${11}
grid_num=${12}
basestation=${13}
proc_id=${14}
amplow=${15}
xf_max_grid=${16}
grid_lat=${17}
grid_lon=${18}
outfile_data=`echo $outps | sed -e 's/\.ps/\.txt/' -e 's/Vespapack/Datapack/'`
outstring=`echo $outps | awk -F"/" '{print $NF}' | sed 's/\.ps//'`
outps=`echo $outps | sed 's/\.ps/_RECORD\.ps/'`
echo outfile $outfile_data
#temps="/NAS/dfrost/Work/Temps/"
plot_type=REDVEL

#DEBUG echo plotcutmin $plotcutmin
#DEBUG echo plotcutmax $plotcutmax
#DEBUG echo numtraces $numtraces
#DEBUG echo sackey $sackey
#DEBUG echo beamdif ${beamdif_onset_trc_SmKS[0]} beamdif ${beamdif_onset_trc_SmKS[1]}
#DEBUG echo SmKS ${SmKS[0]} SmKS ${SmKS[1]}
#DEBUG echo outps $outps

sac_range="-R"$plotcutmin"/"$plotcutmax"/0/"$numtraces
sac_range_text="-R0/10/0/"$numtraces
ampfac=1

\rm -f SACFILELIST_SORTED_TEMP; touch SACFILELIST_SORTED_TEMP
while read cnt dum1 stanm gcarc azi dum2 stla stlo stel stdp sacfile; do
sta_tau=(`awk '/'$stanm'/ {print $3, $4}' tau.output`)
echo $sacfile".arr.cut.fil" $gcarc ${sta_tau[1]} $stanm >> SACFILELIST_SORTED_TEMP
done < STA_DISTANCE_LOC.txt

dist_minmax=(`awk '{print $4}' STA_DISTANCE_LOC.txt | gmt gmtinfo -C | awk '{print $1-(($2-$1)/10), $2+(($2-$1)/10)}'`)
sac_range="-R"$plotcutmin"/"$plotcutmax"/"${dist_minmax[0]}"/"${dist_minmax[1]}
sac_range_text="-R0/10/"${dist_minmax[0]}"/"${dist_minmax[1]}

sac_range_y=`echo ${dist_minmax[0]} ${dist_minmax[1]} | awk '{print $2-$1}'`
sac_frame_y=8
sac_scale_y=`echo $sac_frame_y | awk '{print 15*(1/$1)}'`
sac_scale_y_dbl=`echo $sac_frame_y | awk '{print 7.5*(1/$1)}'`
sac_frame="-JX17c/"$sac_frame_y"c"

#Symbols for predicted phases
symb_direct="-Sc0.2c -Gpurple@30 -W0.04c"
symb_depth="-Sc0.2c -Gdarkgreen@30 -W0.04c"
text_direct=" -F+jCM+a90,+f14,0,purple"
text_depth=" -F+jCM+a90,+f14,0,darkgreen"
box_pred="-W0.06c,purple,-"
line_pred="-Sy2.0c -W0.08c,purple"
horline_pred="-S-2.0c -W0.08c,purple"
box_onset="-W0.06c,red"

#Symbols for picked phases
symb_beam_wholemax="-Sc0.4c -Gwhite@30 -W0.04c"
symb_beam_phasemax="-Sc0.4c -Gblue@30 -W0.04c"
symb_xf_phasemax="-Sc0.4c -Ggreen@30 -W0.04c"
symb_onset="-Sc0.4c -Gred@30 -W0.04c"
line_beam_phasemax="-Sy5.0c -W0.05c,blue"
line_xy_phasemax="-Sy3.0c -W0.05c,green"
line_onset="-W0.06c,red"


gmt psbasemap $sac_range $sac_frame -B20g20:"Time after origin (s)":/1:"Distance (deg)":WSen -K -Y1c -X1.5c > $outps

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

#Calculate moveout of phases for plotting
#DEBUG echo DistTABeampoint $dist
#DEBUG echo DistStaMin ${dist_minmax[0]} DistStaMax ${dist_minmax[1]}

#DistTABeampoint DistStaMin SmKSslow SmKStime
moveout_min=`echo $dist ${dist_minmax[0]} ${beamdif_onset_trc_SmKS[1]} ${beamdif_onset_trc_SmKS[0]} | awk '{print $4-(($1-$2)*$3)}'` #Time of SmKS at this Slowness and Distance
#DistStaMax DistTABeampoint SmKSslow SmKStime
moveout_max=`echo ${dist_minmax[1]} $dist ${beamdif_onset_trc_SmKS[1]} ${beamdif_onset_trc_SmKS[0]} | awk '{print (($1-$2)*$3)+$4}'` #Time of SmKS at this Slowness and Distance

moveout_min_PRED=`echo $dist ${dist_minmax[0]} ${SmKS[1]} ${SmKS[0]} | awk '{print $4-(($1-$2)*$3)}'` #Time of SmKS at this Slowness and Distance
#DistStaMax DistTABeampoint SmKSslow SmKStime
moveout_max_PRED=`echo ${dist_minmax[1]} $dist ${SmKS[1]} ${SmKS[0]} | awk '{print (($1-$2)*$3)+$4}'` #Time of SmKS at this Slowness and Distance


#-----
#Plot moveout of picked phase (time and slow) and predicted phase
#DEBUG echo moveout_min $moveout_min moveout_max $moveout_max
if [ $plot_type == "REDVEL" ]; then

echo -e ${beamdif_onset_trc_SmKS[0]} ${dist_minmax[0]}"\n"${beamdif_onset_trc_SmKS[0]} ${dist_minmax[1]} | gmt psxy $sac_range $sac_frame $box_onset -O -K >> $outps
echo -e ${SmKS[0]} ${dist_minmax[0]}"\n"${SmKS[0]} ${dist_minmax[1]} | gmt psxy $sac_range $sac_frame $box_pred -O -K >> $outps
awk 'NR==1 {print $1, '${dist_minmax[0]}'"\n" $1, '${dist_minmax[1]}'}' $temps"SmKS_slow_pick_range_"$proc_id | gmt psxy $sac_range $sac_frame $box_pred -O -K >> $outps
awk 'NR==3 {print $1, '${dist_minmax[0]}'"\n" $1, '${dist_minmax[1]}'}' $temps"SmKS_slow_pick_range_"$proc_id | gmt psxy $sac_range $sac_frame $box_pred -O -K >> $outps

else
echo -e $moveout_min ${dist_minmax[0]}"\n"$moveout_max ${dist_minmax[1]} | gmt psxy $sac_range $sac_frame $line_onset -O -K >> $outps
echo -e $moveout_min_PRED ${dist_minmax[0]}"\n"$moveout_max_PRED ${dist_minmax[1]} | gmt psxy $sac_range $sac_frame $box_pred -O -K >> $outps
fi


awk -v dist=$dist 'NR==2 {print $1, dist}' $temps"SmKS_picks_"$proc_id | gmt psxy $sac_range $sac_frame $line_beam_phasemax -O -K >> $outps
awk -v dist=$dist 'NR==3 {print $1, dist}' $temps"SmKS_picks_"$proc_id | gmt psxy $sac_range $sac_frame $line_xf_phasemax -O -K >> $outps
#Plot moveout of picked phase (time and slow) and predicted phase
#-----

cnt=0
#NORM_ALL_TO_MAX   trcmax=0
#NORM_ALL_TO_MAX   while read sactrace distance shift; do
#NORM_ALL_TO_MAX   trcmax_one=`sachead $sactrace depmax | awk '{printf "%.12f", $2}'`
#NORM_ALL_TO_MAX   trcmax=`echo $trcmax_one $trcmax | awk '{if ($1>$2) print $1; else print $2}'`
#NORM_ALL_TO_MAX   echo trcmax_one $trcmax_one trcmax $trcmax
#NORM_ALL_TO_MAX   done < SACFILELIST_SORTED_TEMP

while read sactrace distance shift stanm; do
ypos=`echo $cnt 0.5 | awk '{print $1+$2}'` #Y-position to plot sac trace
xpos=`echo $cnt 10.25 | awk '{print ($1/10)+$2}'` #X-position to plot sac label

sac2xy $sactrace sac.xy
max=`gmt gmtinfo -C sac.xy | awk '{if (($3*$3)>($4*$4)) print $3*-1; else if (($3*$3)<($4*$4)) print $4}'`
#DEBUG sachead $sactrace depmax
#DEBUG echo sactrace $sactrace distance $distance max $max
trcmax=`awk '{print $2/('$ampfac')}' sac.xy | gmt gmtinfo -C | awk '{if (($1**2)>($2**2)) print sqrt($1**2); else print sqrt($2**2)}'`

if [ $plot_type == "REDVEL" ]; then
#DEBUG	echo shift $shift min $plotcutmin distance $distance
awk -v shift=$shift '{print $1-shift, '$distance', $2/('$trcmax')}' sac.xy | gmt pswiggle $sac_range $sac_frame -Z$sac_scale_y -W0.015c -O -K >> $outps
else
#awk '{print $1+'$plotcutmin', '$distance', $2/('$max')}' sac.xy | gmt pswiggle $sac_range $sac_frame -Z2 -W0.025c -O -K >> $outps
awk '{print $1, '$distance', $2/('$trcmax')}' sac.xy | gmt pswiggle $sac_range $sac_frame -Z$sac_scale_y -W0.015c -O -K >> $outps
fi
echo 10.25 $distance $stanm | gmt pstext -F+jLM+a0+f10,0,black $sac_range_text $sac_frame -N -O -K >> $outps
#echo $xpos $distance 12 0 0 LM $station | gmt pstext $sac_range_text $sac_frame -N -O -K >> $outps
\rm -f sac.xy


((cnt++))
done < SACFILELIST_SORTED_TEMP

#Plot filtered beam trace
filttime_minmax=(`gmt gmtinfo -C filt_max.xy | awk '{print $1, $2}'`)
vmax=`awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<=(tmax-10)' filt_max.xy | gmt gmtinfo -C | awk '{if (($5*$5)>($6*$6)) print $5*-1; else if (($5*$5)<($6*$6)) print $6}'`
#awk '{print $1, '$dist', (($3/'$vmax')/'$ampfac')}' filt_max.xy | gmt pswiggle $sac_range $sac_frame -Z1 -W0.06c,blue -O -K >> $outps
awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<(tmax-10) {print $1, '$dist', ($3/'$vmax')}' filt_max.xy | gmt pswiggle $sac_range $sac_frame -Z$sac_scale_y_dbl -W0.035c,cadetblue -O -K >> $outps
echo 10.25 $dist BEAM | gmt pstext $sac_range_text $sac_frame -F+jLM+a0+f10,1,cadetblue -N -O -K >> $outps
#Plot filtered beam trace


#Plot XF
filttime_minmax=(`gmt gmtinfo -C xf_max.xy | awk '{print $1, $2}'`)
vmax=`awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<=(tmax-10)' xf_max.xy | gmt gmtinfo -C | awk '{if (($5*$5)>($6*$6)) print $5*-1; else if (($5*$5)<($6*$6)) print $6}'`
#awk '{print $1, '$dist', (($3/'$vmax')/'$ampfac')}' filt_max.xy | gmt pswiggle $sac_range $sac_frame -Z1 -W0.06c,blue -O -K >> $outps
awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<(tmax-10) {print $1, '$dist', ($3/'$vmax')}' xf_max.xy | gmt gmtinfo -C
awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<(tmax-10) {print $1, '$dist'+0.25, ($3/'$vmax')}' xf_max.xy | gmt pswiggle $sac_range $sac_frame -Z$sac_scale_y_dbl -W0.035c,darkgreen -O -K >> $outps
echo 10.25 $dist FTRACE | awk '{print $1, $2+0.5, $3, $4, $5, $6, $7}' | gmt pstext -F+jLM+a0+f10,1,darkgreen $sac_range_text $sac_frame -N -O -K >> $outps


vmax=`awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<=(tmax-10)' filt_dif_max.xy | gmt gmtinfo -C | awk '{if (($5*$5)>($6*$6)) print $5*-1; else if (($5*$5)<($6*$6)) print $6}'`
awk -v tmin=${filttime_minmax[0]} -v tmax=${filttime_minmax[1]} '$1>(tmin+10) && $1<(tmax-10) {print $1, '$dist'-0.25, ($3/'$vmax')}' filt_dif_max.xy | gmt pswiggle $sac_range $sac_frame -Z$sac_scale_y_dbl -W0.035c,purple -O -K >> $outps
echo 10.25 $dist BEAMDIF | awk '{print $1, $2-0.5, $3, $4, $5, $6, $7}' | gmt pstext -F+jLM+a0+f10,1,purple $sac_range_text $sac_frame -N -O -K >> $outps


#echo 10.25 $dist 12 0 1 LM BEAM | gmt pstext $sac_range_text $sac_frame -F+fblue -N -O -K >> $outps
#Plot XF


#If amp is low, then mark with red circle
if [ $amplow == "LOW_AMP" ]; then
echo 9.75 $dist | gmt psxy $sac_range_text $sac_frame -Sc0.4c -Gred -O -K >> $outps
fi

#-------------------------------------------------
#XF SLOW - START  (3) ----------
#-------------------------------------------------
xf_slow_grid=$temps"TEMP_XF_SLOW_GRID_"$proc_id
frame="-JX17c/5.0c"
contcut_xf=50
scale_var=17.25c/2.5c/5.0c/0.25c
xoffset1=0c
yoffset1=8.5c
yoffset_map="-3c"
time_border=40g40
xf_grid_max=`gmt grdinfo $xf_slow_grid | gawk '/z_max/ {print $5}'`
xf_grid_inc=`echo $xf_grid_max | gawk '{printf "%.3f", $1/10}'`
range_vars=(`gmt grdinfo  $xf_slow_grid | grep x_min -A1 | awk '{print $3, $5}'`)
range_grd="-R"${range_vars[0]}"/"${range_vars[1]}"/"${range_vars[2]}"/"${range_vars[3]}




gmt grdimage $xf_slow_grid $range_grd $frame -C$temps"TEMP_XF.cpt_"$proc_id -B$time_border:"Time (sec)":/2:"Slowness (s/deg)":Wsen -X$xoffset1 -Y$yoffset1 -O -K >> $outps
#gmt grdcontour $xf_slow_grid $range_grd $frame -W0.02c,blue -C$xf_grid_inc -Q$contcut_xf -K -O >> $outps
gmt psscale -C$temps"TEMP_XF.cpt_"$proc_id -D$scale_var -B$xf_grid_inc -O -K >> $outps

echo ${SmKS[0]} ${SmKS[1]} | gmt psxy $range_grd $frame $line_pred -O -K >> $outps
echo ${SmKS[0]} ${SmKS[1]} | gmt psxy $range_grd $frame $horline_pred -O -K >> $outps

awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2}' $temps"phases_direct_plot_"$proc_id | gmt psxy $range_grd $frame $symb_direct -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2}' $temps"phases_depth_plot_"$proc_id | gmt psxy $range_grd $frame $symb_depth -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2, $4}' $temps"phases_direct_plot_"$proc_id | gmt pstext $range_grd $frame $text_direct -Xa0.5c -Ya0.5c -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, $2, $4}' $temps"phases_depth_plot_"$proc_id | gmt pstext $range_grd $frame $text_depth -Xa0.5c -Ya0.5c -O -K >> $outps


#Picks:
#Absolute Maximum In Whole Window (blue)
awk 'NR==1 {print $1, $2}' $temps"SmKS_picks_"$proc_id | gmt psxy $range_grd $frame $symb_beam_wholemax -O -K >> $outps
awk 'NR==2 {print $1, $2}' $temps"SmKS_picks_"$proc_id | gmt psxy $range_grd $frame $symb_beam_phasemax -O -K >> $outps
awk 'NR==3 {print $1, $2}' $temps"SmKS_picks_"$proc_id | gmt psxy $range_grd $frame $symb_xf_phasemax -O -K >> $outps
awk 'NR==4 {print $1, $2}' $temps"SmKS_picks_"$proc_id | gmt psxy $range_grd $frame $symb_onset -O -K >> $outps
awk '{print $1, $2}' $temps"SmKS_slow_pick_range_"$proc_id | gmt psxy $range_grd $frame $box_pred -O -K >> $outps


#-------------------------------------------------
#XF SLOW - END (3) ----------
#-------------------------------------------------

#-------------------------------------------------
#XF BAZ - START (4) ----------
#-------------------------------------------------

xf_baz_grid=$temps"TEMP_XF_BAZ_GRID_"$proc_id
xoffset1=0c
yoffset1=5.5c
xf_grid_max=`gmt grdinfo $xf_baz_grid | gawk '/z_max/ {print $5}'`
xf_grid_inc=`echo $xf_grid_max | gawk '{printf "%.f", $1/5}'`
range_vars=(`gmt grdinfo  $xf_baz_grid | grep x_min -A1 | awk '{print $3, $5}'`)
range_grd="-R"${range_vars[0]}"/"${range_vars[1]}"/"${range_vars[2]}"/"${range_vars[3]}


gmt grdimage $xf_baz_grid $range_grd $frame -C$temps"TEMP_XF.cpt_"$proc_id -B$time_border:"Time (sec)":/10g20:"Back-azimuth (deg)":Wsen -Y$yoffset1 -O -K >> $outps
#gmt grdcontour $xf_baz_grid $range_grd $frame -W0.02c,blue -C$xf_grid_inc -Q$contcut_xf -K -O >> $outps

echo ${SmKS[0]} 0 | gmt psxy $range_grd $frame $line_pred -O -K >> $outps
echo ${SmKS[0]} 0 | gmt psxy $range_grd $frame $horline_pred -O -K >> $outps


awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, 0}' $temps"phases_direct_plot_"$proc_id | gmt psxy $range_grd $frame $symb_direct -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, 0}' $temps"phases_depth_plot_"$proc_id | gmt psxy $range_grd $frame $symb_depth -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, 2.5, $4}' $temps"phases_direct_plot_"$proc_id | gmt pstext $range_grd $frame $text_direct -Xa0.5c -Ya0.5c -O -K >> $outps
awk 'NF==4 {if ($1>='$plotcutmin' && $1<='$plotcutmax') print $1, -2.5, $4}' $temps"phases_depth_plot_"$proc_id | gmt pstext $range_grd $frame $text_depth -Xa0.5c -Ya0.5c -O -K >> $outps


#Picks:
#Absolute Maximum In Whole Window (blue)
awk 'NR==1 {print $1, $3}' $temps"SmKS_picks_"$proc_id | gmt psxy $range_grd $frame $symb_beam_wholemax -O -K >> $outps
awk 'NR==2 {print $1, $3}' $temps"SmKS_picks_"$proc_id | gmt psxy $range_grd $frame $symb_beam_phasemax -O -K >> $outps
awk 'NR==3 {print $1, $3}' $temps"SmKS_picks_"$proc_id | gmt psxy $range_grd $frame $symb_xf_phasemax -O -K >> $outps
awk 'NR==4 {print $1, $3}' $temps"SmKS_picks_"$proc_id | gmt psxy $range_grd $frame $symb_onset -O -K >> $outps
awk '{print $1, $2}' $temps"SmKS_baz_pick_range_"$proc_id | gmt psxy $range_grd $frame $box_pred -O -K >> $outps
#-------------------------------------------------
#XF BAZ - END (4) ----------
#-------------------------------------------------

#----------------
#PLOT PICK LABELS - START
#----------------
range_text="-R0/10/0/10"
echo 10.25 10 | gmt psxy $range_text $frame $symb_beam_wholemax -N -O -K >> $outps
echo 10.25 8.5 | gmt psxy $range_text $frame $symb_beam_phasemax -N -O -K >> $outps
echo 10.25 7 | gmt psxy $range_text $frame $symb_xf_phasemax -N -O -K >> $outps
echo 10.25 5.5 | gmt psxy $range_text $frame $symb_onset -N -O -K >> $outps

gmt pstext $frame $range_text -F+jLM+a0+f12,0,black -N -O -K <<EOF >> $outps
10.38 10 Max whole window
10.38 8.5 Beam max
10.38 7 XF max
10.38 5.5 Beam onset
EOF
#----------------
#PLOT PICK LABELS - END
#----------------

#--------
#TEXT ---
#--------
xoffset_txt=20c
yoffset_txt=-17c
frame_text="-JX18c/-5c"
range_text="-R0/10/0/10"

echo ---
echo outfile_data $outfile_data
cat $outfile_data
echo ---
cat $outfile_data | gmt pstext $frame_text $range_text -N -Y$yoffset_txt -X$xoffset_txt -O -K >> $outps
#awk 'NR==11 || NR==12' $outfile_data | gmt pstext $frame_text $range_text -N -F+fred -O -K >> $outps
#awk 'NR==1' $outfile_data | gmt pstext $frame_text $range_text -N -F+fpurple -O -K >> $outps
#echo -0.75 -8.0 14 0 1 LT Grid_num:$grid_num | gmt pstext $frame_text $range_text -N -O -K >> $outps
#echo -0.75 -9.0 14 0 1 LT BeamDist:$dist_RD | gmt pstext $frame_text $range_text -F+fblue -N -O -K >> $outps
#--------
#TEXT ---
#--------


#-------------
#Plot stations
#-------------
xoffset_map=0c
yoffset_map=7.5c
TAlatlon=(`gawk 'BEGIN {A=0; B=0; C=0} {A+=$7; B+=$8; C+=$9; D+=1} END {print A/D, B/D, C/D}' STA_DISTANCE_LOC.txt`)
map_lat_range=(`echo ${TAlatlon[0]} | awk '{print $1-3, $1+3}'`)
map_lon_range=(`echo ${TAlatlon[1]} | awk '{print $1-3, $1+3}'`)
map_range="-R"${map_lon_range[0]}"/"${map_lon_range[1]}"/"${map_lat_range[0]}"/"${map_lat_range[1]}
map_frame="-JW6.0c"
gmt pscoast $map_range $map_frame -B2WSen -Dl -A5000 -N1/0.03c,black -Ggray -N2/0.03c,black -X$xoffset_map -Y$yoffset_map -O -K >> $outps
awk '{print $2, $3}' station_list_TOTAL | gmt psxy $map_range $map_frame -Si0.25c -W0.04c -: -O -K >> $outps
awk '{print $7, $8, $3}' STA_DISTANCE_LOC.txt | gmt psxy $map_range $map_frame -Si0.5c -Gred -W0.04c -N -: -O -K >> $outps
#awk '{print $7, $8, $3}' STA_DISTANCE_LOC.txt | gmt pstext -F+jCM+a0+f12,0,blue $map_range $map_frame -: -O -K -N >> $outps
baz=(`awk 'NR==5 {print $11}' $outfile_data`)
baz_point=(`$py3 $pydir"arccalc_geodesic_STDIN.py" ${TAlatlon[0]} ${TAlatlon[1]} 3 $baz`)
gmt psxy $map_range $map_frame -W0.05c -: -N -O -K <<EOF >> $outps
${TAlatlon[0]} ${TAlatlon[1]}
${baz_point[0]} ${baz_point[1]}
EOF
echo ${TAlatlon[0]} ${TAlatlon[1]} | gmt psxy $map_range $map_frame -Si0.5c -Gyellow -W0.04c -: -O -K >> $outps
echo $grid_lon $grid_lat | gmt psxy $map_range $map_frame -Sc0.3c -Gblack -W0.04c -O -K >> $outps


#Box box =====
sliceidentifier=$outstring
sliceidentifier_rr=$outstring"_RR"

cat >> $outps << EOF
[
/T (BoxName_1_${outstring}_${basestation}_${grid_num})
/FT /Btn
/Rect [1400 4200 1800 4600]
/F 4 /H /O
/BS << /W 1 /S /S >>
/MK << /CA (8) /BC [ 0 ] /BG [ 1 ] >>
/DA (/ZaDb 0 Tf 0 1 0 rg)
/AP << /N << /${sliceidentifier} /null >> >>
/Subtype /Widget
/ANN pdfmark
EOF


#Box box =====
#
##Box box Rerun =====
cat >> $outps << EOF
[
/T (BoxName_2_${outstring}_${basestation}_${grid_num})
/FT /Btn
/Rect [1900 4200 2300 4600]
/F 4 /H /O
/BS << /W 1 /S /S >>
/MK << /CA (8) /BC [ 0 ] /BG [ 1 ] >>
/DA (/ZaDb 0 Tf 0 1 0 rg)
/AP << /N << /${sliceidentifier_rr} /null >> >>
/Subtype /Widget
/ANN pdfmark
EOF
##Box box Rerun =====

##Box box Rerun =====
cat >> $outps <<EOF
[
/Subtype /Widget
/Rect [2400 3800 2800 4600] 		% — position
/T (BoxName_Txt_${outstring}_${basestation}_${grid_num})
/FT /Tx
/DA (/Helv 14 Tf 0 0 1 rg) 					% size and color
/V (Text       Notes)
/AA << >>
/ANN pdfmark
EOF
##Box box Rerun =====

#PLOT SUMMARY TEXT
frame_text_summary="-JX6c/-5c"
yoffset_summary=9c
awk 'NR==1' $temps"SmKS_summary_"$proc_id | gmt pstext $frame_text_summary $range_text -N -F+fblack -Y$yoffset_summary -O -K >> $outps
awk 'NR==2' $temps"SmKS_summary_"$proc_id | gmt pstext $frame_text_summary $range_text -N -F+fblack -O -K >> $outps
awk 'NR==3' $temps"SmKS_summary_"$proc_id | gmt pstext $frame_text_summary $range_text -N -F+fblue -O -K >> $outps
awk 'NR==4' $temps"SmKS_summary_"$proc_id | gmt pstext $frame_text_summary $range_text -N -F+fpurple -O -K >> $outps
awk 'NR==5 || NR==6' $temps"SmKS_summary_"$proc_id | gmt pstext $frame_text_summary $range_text -N -F+fred -O -K >> $outps
awk 'NR==7' $temps"SmKS_summary_"$proc_id | gmt pstext $frame_text_summary $range_text -N -F+fblack -O -K >> $outps
if [ `awk 'NR==8 {print $7}' $temps"SmKS_summary_"$proc_id` == "CONT" ]; then
awk 'NR==8' $temps"SmKS_summary_"$proc_id | gmt pstext $frame_text_summary $range_text -N -F+fred -O -K >> $outps
elif [ `awk 'NR==8 {print $7}' $temps"SmKS_summary_"$proc_id` == "NOCONT" ]; then
awk 'NR==8' $temps"SmKS_summary_"$proc_id | gmt pstext $frame_text_summary $range_text -N -F+fdarkgreen -O -K >> $outps
fi
awk 'NR==1' $temps"SmKS_summary_"$proc_id | gmt pstext $frame_text_summary $range_text -N -F+fblack -O >> $outps

#gmt psbasemap $sac_range $sac_frame -B20/0Wsen -O >> $outps
#-----------D

#gs $outps &

echo ===========================
echo ===========================
echo RECORD END
echo ===========================
echo ===========================
