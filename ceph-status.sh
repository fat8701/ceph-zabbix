#!/bin/bash

ceph_bin="/usr/bin/ceph"
rados_bin="/usr/bin/rados"
zabbix_sender_bin="/usr/bin/zabbix_sender"
zabbix_server="zabbix.cmdrawin.com"
zabbix_host=$(hostname -s)
kv_file="/tmp/zabbix_kv.txt"
send_log="/etc/zabbix/scripts/send.log"


# Initialising variables
# See: http://ceph.com/docs/master/rados/operations/pg-states/
creating=0
active=0
clean=0
down=0
replay=0
splitting=0
scrubbing=0
degraded=0
inconsistent=0
peering=0
repair=0
recovering=0
backfill=0
waitBackfill=0
incomplete=0
stale=0
remapped=0

# Get data
pginfo=$(echo -n "  pgmap $($ceph_bin pg stat)" | sed -n "s/.*pgmap/pgmap/p")
pgtotal=$(echo $pginfo | cut -d' ' -f2 | sed 's/[^0-9]//g')
pgstats=$(echo $pginfo | cut -d':' -f2 | cut -d';' -f1| sed 's/ /\\ /g')
pggdegraded=$(echo $pginfo | sed -n '/degraded/s/.* degraded (\([^%]*\)%.*/\1/p')
if [[ "$pggdegraded" == "" ]]
then
  pggdegraded=0
fi
# unfound (0.004%)
pgunfound=$(echo $pginfo | cut -d';' -f2|sed -n '/unfound/s/.*unfound (\([^%]*\)%.*/\1/p')
if [[ "$pgunfound" == "" ]]
then
  pgunfound=0
fi


clientio=$($ceph_bin -s |grep "client:")
# read  kbps B/s
#rdbps=$(echo $clientio | sed -n '/client/s/.* \([0-9]* .\?\)B\/s rd.*/\1/p' | sed -e "s/K/*1000/ig;s/M/*1000*1000/i;s/G/*1000*1000*1000/i;s/E/*1000*1000*1000*1000/i" | bc)
rdbps=$(echo $clientio | sed -n '/client:/s/.* \([0-9\.]* .\{0,2\}\)B\/s rd.*/\1/p'| sed -e "s/Ki/*1000/ig;s/Mi/*1000*1000/ig;s/Gi/*1000*1000*1000/ig;s/Ei/*1000*1000*1000*1000/ig" | bc)
# write kbps B/s
wrbps=$(echo $clientio | sed -n '/client:/s/.* \([0-9\.]* .\{0,2\}\)B\/s wr.*/\1/p'| sed -e "s/Ki/*1000/ig;s/Mi/*1000*1000/ig;s/Gi/*1000*1000*1000/ig;s/Ei/*1000*1000*1000*1000/ig" | bc)
#wrbps=$(echo $clientio | sed -n '/client/s/.* \([0-9]* .\?\)B\/s wr.*/\1/p' | sed -e "s/K/*1000/ig;s/M/*1000*1000/i;s/G/*1000*1000*1000/i;s/E/*1000*1000*1000*1000/i" | bc)
if [[ "$rdbps" == "" ]]
then
  rdbps=0
fi

# write kbps B/s
#wrbps=$(echo $pginfo | sed -n '/pgmap/s/.* \([0-9]* .\?\)B\/s wr.*/\1/p' | sed -e "s/K/*1000/ig;s/M/*1000*1000/i;s/G/*1000*1000*1000/i;s/E/*1000*1000*1000*1000/i" | bc)
if [[ "$wrbps" == "" ]]
then
  wrbps=0
fi

# ops
rops=$(echo $clientio | sed -n '/client/s/.* \([0-9\.]* k\?\)op\/s rd.*/\1/p'|sed -e "s/K/*1000/ig"|bc)
if [[ "$rops" == "" ]]
then
  rops=0
fi

wops=$(echo $clientio | sed -n '/client/s/.* \([0-9\.]* k\?\)op\/s wr.*/\1/p'|sed -e "s/K/*1000/ig"|bc)
if [[ "$wops" == "" ]]
then
  wops=0
fi

ops=$(echo $rops + $wops | bc)

#ops=$(echo $pginfo | sed -n '/pgmap/s/.* \([0-9]*\) op\/s.*/\1/p')
#if [[ "$ops" == "" ]]
#then
#  ops=0
#fi


# Explode array
IFS=', ' read -a array <<< "$pgstats"
for element in "${array[@]}"
do
    element=$(echo "$element" | sed 's/^ *//g')
    # Get elements
    number=$(echo $element | cut -d' ' -f1)
    data=$(echo $element | cut -d' ' -f2)

    # Agregate data
    if [ "$(echo $data | grep creating | wc -l)" == 1 ]
    then
	  creating=$(echo $creating+$number|bc)
    fi

    if [ "$(echo $data | grep active | wc -l)" == 1 ]
    then
	  active=$(echo $active+$number|bc)
    fi

    if [ "$(echo $data | grep clean | wc -l)" == 1 ]
    then
	  clean=$(echo $clean+$number|bc)
    fi

    if [ "$(echo $data | grep down | wc -l)" == 1 ]
    then
	  down=$(echo $down+$number|bc)
    fi

    if [ "$(echo $data | grep replay | wc -l)" == 1 ]
    then
	  replay=$(echo $replay+$number|bc)
    fi

    if [ "$(echo $data | grep splitting | wc -l)" == 1 ]
    then
	  splitting=$(echo $splitting+$number|bc)
    fi

    if [ "$(echo $data | grep scrubbing | wc -l)" == 1 ]
    then
	  scrubbing=$(echo $scrubbing+$number|bc)
    fi

    if [ "$(echo $data | grep degraded | wc -l)" == 1 ]
    then
	  degraded=$(echo $degraded+$number|bc)
    fi

    if [ "$(echo $data | grep inconsistent | wc -l)" == 1 ]
    then
	  inconsistent=$(echo $inconsistent+$number|bc)
    fi

    if [ "$(echo $data | grep peering | wc -l)" == 1 ]
    then
	  peering=$(echo $peering+$number|bc)
    fi

    if [ "$(echo $data | grep repair | wc -l)" == 1 ]
    then
	  repair=$(echo $repair+$number|bc)
    fi

    if [ "$(echo $data | grep recovering | wc -l)" == 1 ]
    then
	  recovering=$(echo $recovering+$number|bc)
    fi

    if [ "$(echo $data | grep backfill | wc -l)" == 1 ]
    then
	  backfill=$(echo $backfill+$number|bc)
    fi

    if [ "$(echo $data | grep "wait-backfill" | wc -l)" == 1 ]
    then
	  waitBackfill=$(echo $waitBackfill+$number|bc)
    fi

    if [ "$(echo $data | grep incomplete | wc -l)" == 1 ]
    then
	  incomplete=$(echo $incomplete+$number|bc)
    fi

    if [ "$(echo $data | grep stale | wc -l)" == 1 ]
    then
	  stale=$(echo $stale+$number|bc)
    fi

    if [ "$(echo $data | grep remapped | wc -l)" == 1 ]
    then
	  remapped=$(echo $remapped+$number|bc)
    fi
done

ceph_osd_count=$($ceph_bin osd dump |grep "^osd"| wc -l)

ceph_warn_without_tag=$(ceph health detail|egrep -v "(noout|noscrub|nodeep-scrub) flag\(s\) set"|egrep -v "cephfs failing to respond to cache pressure|clients failing to respond to cache pressure"|wc -l)

ceph_mds_memory_percent=$(echo "scale=2; `ceph daemon mds.$zabbix_host cache status|jq '.pool.bytes'`*100/`ceph daemon mds.$zabbix_host config show |jq '.mds_cache_memory_limit'|sed 's/\"//g'`" | bc )

function ceph_osd_up_percent()
{
  OSD_DOWN=$($ceph_bin osd dump |grep "^osd"| awk '{print $1 " " $2 " " $3}'|grep up|wc -l)
  COUNT=$(echo "scale=2; $OSD_DOWN*100/$ceph_osd_count" |bc)
  if [[ "$COUNT" != "" ]]
  then
    echo $COUNT
  else
    echo "0"
  fi
}

function ceph_osd_in_percent()
{
  OSD_DOWN=$($ceph_bin osd dump |grep "^osd"| awk '{print $1 " " $2 " " $3}'|grep in|wc -l)
  COUNT=$(echo "scale=2; $OSD_DOWN*100/$ceph_osd_count" | bc)
  if [[ "$COUNT" != "" ]]
  then
    echo $COUNT
  else
    echo "0"
  fi
}

function ceph_mon_get_active()
{
  ACTIVE=$($ceph_bin status|sed -n '/mon:/s/.* \([0-9]*\) daemons.*/\1/p')
  if [[ "$ACTIVE" != "" ]]
  then
    echo $ACTIVE
  else
    echo 0
  fi
}

function ceph_get()
{
# Return the value
case $1 in
  health)
    status=$($ceph_bin health | awk '{print $1}')
    case $status in
      HEALTH_OK)
        echo 0
      ;;
      HEALTH_WARN)
        echo 1
      ;;
      HEALTH_ERR)
        echo 2
      ;;
      *)
        echo -1
      ;;
    esac
  ;;
  health_detail)
    $ceph_bin health detail > /tmp/ceph_detail.txt
    sed -i 's/$/\\n/g' /tmp/ceph_detail.txt
    cat /tmp/ceph_detail.txt
  ;;
  health_status)
    status=$($ceph_bin -s)
    $ceph_bin -s > /tmp/ceph_status.txt
    sed -i 's/$/\\n/g' /tmp/ceph_status.txt
    cat /tmp/ceph_status.txt
  ;;
  rados_total)
    #$rados_bin df | grep "total_space"| cut -d ' ' -f 7
    $rados_bin df|grep "total_space"| awk -F ' ' '{print $2$3}'| sed -n 's/\(.*\)iB/\1/p'|sed -e "s/K/*1000/ig;s/M/*1000*1000/i;s/G/*1000*1000*1000/i;s/T/*1000*1000*1000*1000/i" | bc
  ;;
  rados_used)
    #$rados_bin df | grep "total_used"| cut -d ' ' -f 8
    $rados_bin df|grep "total_used"| awk -F ' ' '{print $2$3}'| sed -n 's/\(.*\)iB/\1/p'|sed -e "s/K/*1000/ig;s/M/*1000*1000/i;s/G/*1000*1000*1000/i;s/T/*1000*1000*1000*1000/i" | bc
  ;;
  rados_free)
    #$rados_bin df | grep "total_avail"| cut -d ' ' -f 7
    $rados_bin df|grep "total_avail"| awk -F ' ' '{print $2$3}' | sed -n 's/\(.*\)iB/\1/p'|sed -e "s/K/*1000/ig;s/M/*1000*1000/i;s/G/*1000*1000*1000/i;s/T/*1000*1000*1000*1000/i" | bc
  ;;
  rados_used_ratio)
          #a=`$rados_bin df | grep "total_used"| cut -d ' ' -f 8`
          a=`$rados_bin df|grep "total_used"| awk -F ' ' '{print $2 $3}' | sed -n 's/\(.*\)iB/\1/p'|sed -e "s/K/*1000/ig;s/M/*1000*1000/i;s/G/*1000*1000*1000/i;s/T/*1000*1000*1000*1000/i" | bc`
          #b=`$rados_bin df | grep "total_space"| cut -d ' ' -f 7`
          b=`$rados_bin df|grep "total_space"| awk -F ' ' '{print $2 $3}' | sed -n 's/\(.*\)iB/\1/p'|sed -e "s/K/*1000/ig;s/M/*1000*1000/i;s/G/*1000*1000*1000/i;s/T/*1000*1000*1000*1000/i" | bc`
          c=$(echo "scale=2;$a/$b"|bc)
          echo $c
  ;;
  mon)
    ceph_mon_get_active
  ;;
  count)
    echo $ceph_osd_count
  ;;
  up)
    ceph_osd_up_percent
  ;;
  "in")
    ceph_osd_in_percent
  ;;
  degraded_percent)
    echo $pggdegraded
  ;;
  pgtotal)
    echo $pgtotal
  ;;
  creating)
    echo $creating
  ;;
  active)
    echo $active
  ;;
  clean)
    echo $clean
  ;;
  down)
    echo $down
  ;;
  replay)
    echo $replay
  ;;
  splitting)
    echo $splitting
  ;;
  scrubbing)
    echo $scrubbing
  ;;
  degraded)
    echo $degraded
  ;;
  inconsistent)
    echo $inconsistent
  ;;
  peering)
    echo $peering
  ;;
  repair)
    echo $repair
  ;;
  recovering)
    echo $recovering
  ;;
  backfill)
    echo $backfill
  ;;
  waitBackfill)
    echo $waitBackfill
  ;;
  incomplete)
    echo $incomplete
  ;;
  stale)
    echo $stale
  ;;
  remapped)
    echo $remapped
  ;;
   rops)
    echo $rops
  ;;
 wops)
    echo $wops
  ;;
  ops)
    echo $ops
  ;;
  wrbps)
    echo $wrbps
  ;;
  rdbps)
    echo $rdbps
  ;;
  warn_without_tag)
    echo $ceph_warn_without_tag
  ;;
  mds_memory_percent)
    echo $ceph_mds_memory_percent
  ;;
  esac
}

function get_kv()
{
	echo - ceph.health $(ceph_get health) \\n 
	echo - ceph.count $(ceph_get count) \\n 
	echo - ceph.osd_in $(ceph_get in) \\n
	echo - ceph.osd_up $(ceph_get up) \\n
	echo - ceph.active $(ceph_get active) \\n 
	echo - ceph.backfill $(ceph_get backfill) \\n 
	echo - ceph.clean $(ceph_get clean) \\n
	echo - ceph.creating $(ceph_get creating) \\n 
	echo - ceph.degraded $(ceph_get degraded) \\n
	echo - ceph.degraded_percent $(ceph_get degraded_percent) \\n 
	echo - ceph.down $(ceph_get down) \\n
	echo - ceph.incomplete $(ceph_get incomplete) \\n 
	echo - ceph.inconsistent $(ceph_get inconsistent) \\n 
	echo - ceph.peering $(ceph_get peering) \\n
	echo - ceph.recovering $(ceph_get recovering) \\n 
	echo - ceph.remapped $(ceph_get remapped) \\n
	echo - ceph.repair $(ceph_get repair) \\n
	echo - ceph.replay $(ceph_get replay) \\n
	echo - ceph.scrubbing $(ceph_get scrubbing) \\n 
	echo - ceph.splitting $(ceph_get splitting) \\n
	echo - ceph.stale $(ceph_get stale) \\n
	echo - ceph.pgtotal $(ceph_get pgtotal) \\n 
	echo - ceph.waitBackfill $(ceph_get waitBackfill) \\n 
	echo - ceph.mon $(ceph_get mon) \\n 
	echo - ceph.rados_total $(ceph_get rados_total) \\n
	echo - ceph.rados_used $(ceph_get rados_used) \\n
	echo - ceph.rados_free $(ceph_get rados_free) \\n
	echo - ceph.rados_used_ratio $(ceph_get rados_used_ratio) \\n
	echo - ceph.wrbps $(ceph_get wrbps) \\n
	echo - ceph.rdbps $(ceph_get rdbps) \\n 
	echo - ceph.ops $(ceph_get ops) \\n 
	echo - ceph.rops $(ceph_get rops) \\n 
	echo - ceph.wops $(ceph_get wops) \\n
	echo - ceph.mds_memory_percent $(ceph_get mds_memory_percent) \\n
	echo - ceph.tag $(ceph_get warn_without_tag) 

#        echo -n "- ceph.health_status \""$(ceph_get health_status)"\"" \\n
#	echo -n "- ceph.health_detail \""$(ceph_get health_detail)"\"" 
	
}
#sleep $(echo $RANDOM%50|bc)
echo -e $(get_kv) > $kv_file
$zabbix_sender_bin -vv --zabbix-server $zabbix_server --host $zabbix_host -k ceph.health_status -o "`$ceph_bin -s`">> $send_log 2>&1
$zabbix_sender_bin -vv --zabbix-server $zabbix_server --host $zabbix_host -k ceph.health_detail -o "`$ceph_bin health detail`" >> $send_log 2>&1
$zabbix_sender_bin -vv --zabbix-server $zabbix_server --host $zabbix_host --input-file $kv_file > $send_log 2>&1

