#!/bin/bash

#
# Course: High Performance Computing 2021/2022
# 
# Lecturer: Francesco Moscato	fmoscato@unisa.it
#
# Group:
# Salvatore Grimaldi  0622701742  s.grimaldi29@studenti.unisa.it              
# Enrico Maria Di Mauro  0622701706  e.dimauro5@studenti.unisa.it
# Allegra Cuzzocrea  0622701707  a.cuzzocrea2@studenti.unisa.it
#
# Copyright (C) 2021 - All Rights Reserved 
#
# This file is part of Contest-OMP.
#
# Contest-OMP is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Contest-OMP is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Contest-OMP.  If not, see <http://www.gnu.org/licenses/>.
#

TIMEFORMAT='%3U;%3E;%3S;%P'
TIMESTAMP=$(date +%F.%T)

NMEASURES=200
ARRAY_SIZE=(10000 100000 1000000 10000000) #carico
ARRAY_THS=(0 1 2 4 8 16)
ARRAY_OPT=(0 1 2 3)


SCRIPTPATH=$2

for size in "${ARRAY_SIZE[@]}"; do
	for nTh in "${ARRAY_THS[@]}"; do
		for opt in "${ARRAY_OPT[@]}"; do

            nThStr=$(printf "%02d" $nTh)
				
            OUT_FILE=$SCRIPTPATH/measure/$TIMESTAMP/SIZE-$size-O$opt/SIZE-$size-NTH-$nThStr-O$opt.csv
            
            mkdir -p $(dirname $OUT_FILE)
            
            echo $(basename $OUT_FILE)
            echo 'nThread;timeInt;user;real;sys;pCPU'>$OUT_FILE 

            for (( nExec = 0 ; nExec < $NMEASURES ; nExec += 1 )) ; do

                (time $1/eseguibileO$opt $nTh $size)2>&1 | sed -e 's/,/./g' -e 's/\n/;/g'  >> $OUT_FILE 
                printf "\r> %5d/%d %3.1d%% [ " $(expr $nExec + 1) $NMEASURES $(expr \( \( $nExec + 1  \) \* 100 \) / $NMEASURES)
                printf "=%.0s" $(seq -s " " 1 $(expr \( $nExec \* 40 \) / $NMEASURES))
                printf " %.0s" $(seq -s " " 1 $(expr 40 - \( $nExec \* 40 \) / $NMEASURES))
                printf "] "
                
            done

            printf "\n"

        done
    done
done