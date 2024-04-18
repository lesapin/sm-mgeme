#!/bin/bash

# Read .stat files output by ServerMon plugin. Parse them into a
# gnuplot .dat file. Use gnuplot to create statistics of server activity.

args=("$@")

if [ $# -eq 0 ] 
then
	title="Player activity - `date +%m\ %Y`"
else
	title=${args[0]}
fi

filename=${title// /_}

LOGS=`ls *.stats`
DATFILE="${filename}.dat"
IMGFILE="${filename}.png"

IFS=$'\n'

# print .dat header
printf "# gnuplot datfile - %s\n" $title > $DATFILE
printf "# DATE\tMANHOURS\tACTIVEHOURS\tMAXCLIENTS\tUNIQUECLIENTS\tCONNECTIONS\n" >> $DATFILE

nLogs=0
nConnections=0
maxclients=0
maxclients_alltime=0
active_hours=0

today=`date +%m%d`
firstlog=$today

# Parse log files

for log in $LOGS;
do
	if [ $nLogs -eq 0 ];
	then
		firstlog=${log:5:4}
	fi

	nLogs=$((nLogs+1))
	
	# Date is used as x-axis key
	printf "${log:5:4}\t" >> $DATFILE

	# Parse all lines except individual player activity
	while IFS=' ' read -ra line
	do
		if [[ "${line[0]}" != PLAYER ]]; then
			printf "${line[1]}\t" >> $DATFILE
		fi
		if [[ "${line[0]}" == ACTIVEHOURS ]]; then
			active_hours=$((active_hours+${line[1]}))
		fi
		if [[ "${line[0]}" == MAXCLIENTS ]]; then
			maxclients=$((maxclients+${line[1]}))
			if [ ${line[1]} -gt $maxclients_alltime ]; then
				maxclients_alltime=${line[1]}
			fi
		fi
		if [[ "${line[0]}" == CONNECTIONS ]]; then
			nConnections=$((nConnections+${line[1]}))
		fi
	done < $log

	printf '\n' >> $DATFILE
done

avg_maxclients=$((maxclients/nLogs))
avg_activity=$(((active_hours/nLogs)/60/60))
avg_empty=$((24-avg_activity))


# Plotting

if [ $nLogs -lt 4 ]
then
	echo "Too few data points, less than 4"
	exit 4
elif [ $nLogs -gt 31 ]
then
	echo "Too many data points, over 31"
	exit 31
fi

gnuplot <<- EOF
	set title "$title" tc rgb 0xffffff
	set tics font ",9"
	set key outside tc rgb 0xffffff
	set border lc rgb 0xffffff

	set xlabel "Date" tc rgb 0xffffff
	set xdata time
	set timefmt "%m%d"
	set xtics format "%d." time
	set xtics 60*60*24

	set ylabel "Sum of every clients playtime\n[h]" tc rgb 0xffffff
        set yrange [0 : 50]
	set ytics nomirror tc "yellow"

	set y2label "Number of unique clients" tc rgb 0xffffff
	set y2range [0 : 100]
	set y2tics nomirror tc rgb 0xb7f8f1 0,5

	set label 1 at screen 0.848,0.75  \
	    "Activity (avg/day)\n active: $avg_activity hours\n empty: $avg_empty hours" \
            tc rgb 0xffffff

	set label 2 at screen 0.848,0.60 "Connections\n $nConnections" tc rgb 0xffffff
	set label 3 at screen 0.848,0.50 "MaxClients (avg/day)\n $avg_maxclients" tc rgb 0xffffff
	set label 4 at screen 0.848,0.40 "MaxClients (alltime)\n $maxclients_alltime" tc rgb 0xffffff

 	# playtime trend
	k=10e-10
	f(x) = k*x + b 
        fit f(x) "$DATFILE" u 1:(column(2)/60/60) via k,b

	set term pngcairo size 1200,620 transparent truecolor dashed
	set output "$IMGFILE"

	plot ["${firstlog}":"${today}"] \
             "$DATFILE" u 1:5 axes x1y2 t 'unique clients' w boxes lc rgb 0xb7f8f1, \
	     "$DATFILE" u 1:(column(2)/60/60) t 'man-hours' w points lw 2 lc "yellow", \
	     f(x) t 'playtime trend' with lines dt 2 lc "yellow"
EOF

mv -f $IMGFILE /var/www/statarchive/$IMGFILE

