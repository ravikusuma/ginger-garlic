#!/bin/bash
#####################################################################################
#                                                                                   #
#       This Script is meant for restoring Cassandra tables from snapshot backup    #
#                                **********                                         #
#       Pre-requiste to run this script: conf file with three fields/columns        # 
#             f1: Keyspace_name                                                     #
#             f2: Table_name                         			            #
#             f3: backup_directory name                                             #
#                -Static or runtime conf file generation(Not a priority)            #             
#                -Integrate or call this script from Master script                  #
#                                                                                   #
#####################################################################################

#set -x

###################################
#Backup variables --Do not change #
###################################
script_name=restore_snapshot.sh; export script_name
#DATE=`date '+%d%h%Y_%H:%M'`
host=`hostname`; export host
logs=/tmp/logs; export logs
data=/var/lib/cassandra/data; export data
master_bkp_log=${logs}/snap_restore_${host}_master_$(date +%b%d).log; export master_bkp_log
configfile=/tmp/restore_snapshot_table.conf; export configfile
timestamp="`date '+%Y%m%d%H%M%S'`"
OUTF=${master_bkp_log}
#FAILED=0
echo "---------------------------------------------------------------------------"> ${master_bkp_log}
echo "Execution of the restore $script_name begins on `date`" >> ${master_bkp_log}
echo "---------------------------------------------------------------------------">> ${master_bkp_log}

sed 1d "$configfile" | while IFS=":" read -r f1 f2 f3
do
export ks="$f1"
export tn="$f2"
export bn="$f3"
logfile="/tmp/logs/${ks}_${tn}_restore_${host}_$timestamp.log"

if [ -z "$ks" ]
then
 echo "          ****************                         "
 echo "Warning: Keyspace name is missing in config file: $configfile"
 echo "          ****************                         "
elif [ ! -n "$tn" ]
then
 echo "          ****************                         "
 echo "Warning: Table name  is missing in config file: $configfile"
 echo "          ****************                         "
elif [ -z "$bn" ]
then
 echo "          ****************                         "
 echo "Warning: Backup directory name is missing in config file: $configfile"
 echo "          ****************                         "
#[ $PS1 ] && return || exit;
fi
(
echo "              "
echo "Keyspace : $ks" 
echo "Table    : $tn" 
echo "Backup_in_use    : $bn" 
echo "              "
echo "Table being restored : ${ks}.${tn}  using backup: $bn" 
echo "              "

/usr/bin/cp -R $data/$ks/$tn* $data/$ks/preimage-$tn-$(date +%b%d)

RET_VAL=$?

if [ "$RET_VAL" -ne "0" ] 
then
echo "Failed to take the pre-image of the existing directory-possible permission issue for user in execution or directory structure is incorrect "
exit 101
fi

/usr/bin/cp $data/$ks/$tn*/snapshots/$bn/* $data/$ks/$tn*

RC=$?
if [ "$RC" -ne "0" ] 
then
        echo "Failed to copy the snapshot to the SSTABLES directory"
        exit 102
fi

/usr/bin/nodetool refresh $ks $tn

VAL=$?

if [ "$VAL" -ne "0" ]
then
      echo " Nodetool Refresh Failed"
      exit 103
fi

) >& $logfile
RETURN_STATUS=$?

if [ $RETURN_STATUS != 0 ]
then
 echo "###########################################################################">>${master_bkp_log}
 echo "#                                                                         #">>${master_bkp_log}
 echo "#                                                                         #">>${master_bkp_log}
 echo "#                            RESTORE FAILED                               #">>${master_bkp_log}
 echo "   check the logfile:                                                      ">>${master_bkp_log}
 echo "    $logfile                                                               ">>${master_bkp_log}
 echo "#                                                                         #">>${master_bkp_log}
 echo "#                                                                         #">>${master_bkp_log}
 echo "###########################################################################">>${master_bkp_log}
else
 echo "###########################################################################">>${master_bkp_log}
 echo "#                                                                         #">>${master_bkp_log}
 echo "#                                                                         #">>${master_bkp_log}
 echo "#                            RESTORE SUCCESS                              #">>${master_bkp_log}
 echo "   verify the logfile:                                                     ">>${master_bkp_log}
 echo "    $logfile                                                               ">>${master_bkp_log}
 echo "#                                                                         #">>${master_bkp_log}
 echo "#                                                                         #">>${master_bkp_log}
 echo "###########################################################################">>${master_bkp_log}
fi
sleep 2;
done >> ${master_bkp_log}
#done < "$configfile" >> ${master_bkp_log}

echo "Master logfile: $OUTF "
exit $RETURN_STATUS
echo "---------------------------------------------------------------------------">> ${master_bkp_log}
echo "Execution of the $script_name ended on `date`" >> ${master_bkp_log}
echo "---------------------------------------------------------------------------">> ${master_bkp_log}
