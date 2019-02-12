#! /bin/bash

# This script generates a workload on your ADWC instance using the out-of-the-box SSB sample data. It allows to pick the database services and the level of concurrency for the workload.
# Using This Script
# - Have local sqlplus installed on your machine
# - Create three symbolic links to sqlplus named as sqlpluslow, sqlplusmedium, sqlplushigh. This is to make monitoring easier for different database services
# 		For example;
#		ln -s /Applications/instantclient_12_2/sqlplus sqlpluslow
#		ln -s /Applications/instantclient_12_2/sqlplus sqlplusmedium
#		ln -s /Applications/instantclient_12_2/sqlplus sqlplushigh
# - Configure SQL*Net connection to your ADWC instance and set the environment variable TNS_ADMIN to the right directory
#https://docs.oracle.com/en/cloud/paas/autonomous-data-warehouse-cloud/user/connect-preparing.html#GUID-EFAFA00E-54CC-47C7-8C71-E7868279EF3B
# - Run the script with the right parameters. Pick the level of concurrency for each database services based on your requirements.
#	For example: 
#	./runworkload.sh -d testdw -p adminpass -l 2 -m 2 -h 2 ----> Connects to the database TESTDW using the admin password adminpass and runs 2 concurrent queries each in LOW, MEDIUM, HIGH services


usage() { echo "Usage: $0 -d <database_name> -p <admin_password> -l <no_of_low_sessions_to_start> -m <no_of_medium_sessions_to_start> -h <no_of_high_sessions_to_start>" 1>&2; exit 1; }

runQuery()
{
./sqlplus$1 /nolog <<EOF

connect admin/${p}@${d}_$1

rem q1_2
select /*+ no_result_cache */ sum(lo_extendedprice*lo_discount) as revenue
from ssb.lineorder, ssb.dwdate
where lo_orderdate = d_datekey
and d_yearmonthnum = 199401
and lo_discount between 4 and 6
and lo_quantity between 26 and 35; 
 
rem q2_2
select /*+ no_result_cache */ sum(lo_revenue), d_year, p_brand1
from ssb.lineorder, ssb.dwdate, ssb.part, ssb.supplier
where lo_orderdate = d_datekey
and lo_partkey = p_partkey
and lo_suppkey = s_suppkey
and p_brand1 between 'MFGR#2221' and 'MFGR#2228'
and s_region = 'ASIA'
group by d_year, p_brand1
order by d_year, p_brand1; 
  
rem q3_2
select /*+ no_result_cache */ c_city, s_city, d_year, sum(lo_revenue) as revenue
from ssb.customer, ssb.lineorder, ssb.supplier, ssb.dwdate
where lo_custkey = c_custkey
and lo_suppkey = s_suppkey
and lo_orderdate = d_datekey
and c_nation = 'UNITED STATES'
and s_nation = 'UNITED STATES'
and d_year >= 1992 and d_year <= 1997
group by c_city, s_city, d_year
order by d_year asc, revenue desc; 
  
rem q3_4
select /*+ no_result_cache */ c_city, s_city, d_year, sum(lo_revenue) as revenue
from ssb.customer, ssb.lineorder, ssb.supplier, ssb.dwdate
where lo_custkey = c_custkey
and lo_suppkey = s_suppkey
and lo_orderdate = d_datekey
and (c_city='UNITED KI1' or
c_city='UNITED KI5')
and (s_city='UNITED KI1' or
s_city='UNITED KI5')
and d_yearmonth = 'Dec1997'
group by c_city, s_city, d_year
order by d_year asc, revenue desc; 

exit;
EOF
}

while getopts ":d:p:l:m:h:" o; do
    case "${o}" in
        d)
            d=${OPTARG}
            ;;
        p)
            p=${OPTARG}
            ;;
        l)
            l=${OPTARG}
            ;;
        m)
            m=${OPTARG}
            ;;
        h)
            h=${OPTARG}
            ;;

        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if ([ -z "${d}" ] || [ -z "${p}" ]) || ([ -z "${l}" ] && [ -z "${m}" ] && [ -z "${h}" ]) ; then
    usage
else

  countM=`ps -ef|egrep [s]qlplusm|wc -l`
  echo "Target number of MEDIUM sessions: $m"
  echo "Current number of MEDIUM sessions: $countM"

  countL=`ps -ef|egrep [s]qlplusl|wc -l`
  echo "Target number of LOW sessions: $l"
  echo "Current number of LOW sessions: $countL"

  countH=`ps -ef|egrep [s]qlplush|wc -l`
  echo "Target number of HIGH sessions: $h"
  echo "Current number of HIGH sessions: $countH"

 while true
 do
 	if [[ $countL -lt $l ]]
	then
                runQuery low >> /dev/null &
                slp=`cat /dev/urandom | LC_CTYPE=C tr -cd '0-1' | head -c 1`
                echo "Sleeping for $slp secs before starting next session..."
                sleep $slp
                countL=`ps -ef|egrep [s]qlplusl|wc -l`
                echo "Current number of LOW sessions: $countL"

	elif [[ $countM -lt $m ]]
	then
                runQuery medium >> /dev/null &
                slp=`cat /dev/urandom | LC_CTYPE=C tr -cd '0-1' | head -c 1`
                echo "Sleeping for $slp secs before starting next session..."
                sleep $slp
                countM=`ps -ef|egrep [s]qlplusm|wc -l`
                echo "Current number of MEDIUM sessions: $countM"

        elif [[ $countH -lt $h ]]
	then
                runQuery high >> /dev/null &
                slp=`cat /dev/urandom | LC_CTYPE=C tr -cd '0-1' | head -c 1`
                echo "Sleeping for $slp secs before starting next session..."
                sleep $slp
                countH=`ps -ef|egrep [s]qlplush|wc -l`
                echo "Current number of HIGH sessions: $countH"
	else
		echo "All sessions active, sleeping for now..."
                slp=`cat /dev/urandom | LC_CTYPE=C tr -cd '0-1' | head -c 2`
                sleep $slp
 	fi

	countM=`ps -ef|egrep [s]qlplusm|wc -l`
	countL=`ps -ef|egrep [s]qlplusl|wc -l`
	countH=`ps -ef|egrep [s]qlplush|wc -l`

 done

fi 