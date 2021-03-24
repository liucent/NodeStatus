#!/bin/bash

UPDATE_URI="https://api.serverless.com/api/update"
TOKEN="" # api token
INTERVAL=2 # Update interval should be less than 60s

# Node info
NAME="iKoula" # Server name should be unique
TYPE="KVM"
HOST="SanJose"
LOCATION="us" # Country code


command_exists () {
    type "$1" &> /dev/null ;
}

if command_exists netcat; then
    NETBIN="netcat"
elif command_exists nc; then
    NETBIN="nc"
else
    echo "netcat not found, install it."
    exit 1
fi

RUNNING=true
clean_up () {
    echo "Quit." >&2
    RUNNING=false
    rm -f /tmp/fuckbash
}

trap clean_up SIGINT SIGTERM EXIT
STRING=""

while $RUNNING; do
    rm -f /tmp/fuckbash
    PREV_TOTAL=0
    PREV_IDLE=0
    AUTH=true
    TIMER=0

    while $RUNNING; do
        if $AUTH; then
            echo "${NAME}:${TOKEN}"
            AUTH=false
        fi
        sleep $INTERVAL
        if ! $RUNNING; then
            exit 0
        fi

        # Connectivity
        if [ $TIMER -le 0 ]; then
            IP6_ADDR="2001:4860:4860::8888"
            IP4_ADDR="8.8.8.8"
            if ping -i 0.2 -c 3 -w 3 $IP4_ADDR &> /dev/null; then
                Online4=true
            else
                Online4=false
            fi
            if ping6 -i 0.2 -c 3 -w 3 $IP6_ADDR &> /dev/null; then
                Online6=true
            else
                Online6=false
            fi
            TIMER=10
        else
            let TIMER-=1*INTERVAL
        fi

        # Uptime
        Uptime=$(uptime | awk -F',' '{print $1}' | awk -F'up' '{print $2}' | sed 's/[[:space:]]//g')

        # Load Average
        Load=$(awk '{ print $1 }' /proc/loadavg)

        # Memory
        MemTotal=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        MemFree=$(awk '/MemFree/ {print $2}' /proc/meminfo)
        Cached=$(awk '/\<Cached\>/ {print $2}' /proc/meminfo)
        MemUsed=$(($MemTotal - ($Cached + $MemFree)))
        SwapTotal=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
        SwapFree=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
        SwapUsed=$(($SwapTotal - $SwapFree))

        # Disk
        HDD=$(df -Tlm --total -t ext4 -t ext3 -t ext2 -t reiserfs -t jfs -t ntfs -t fat32 -t btrfs -t fuseblk -t zfs -t simfs -t xfs 2>/dev/null | tail -n 1)
        HDDTotal=$(echo -n ${HDD} | awk '{ print $3 }')
        HDDUsed=$(echo -n ${HDD} | awk '{ print $4 }')

        # CPU
        # Get the total CPU statistics, discarding the 'cpu ' prefix.
        CPU=($(sed -n 's/^cpu\s//p' /proc/stat))
        IDLE=${CPU[3]} # Just the idle CPU time.
        # Calculate the total CPU time.
        TOTAL=0
        for VALUE in "${CPU[@]}"; do
            let "TOTAL=$TOTAL+$VALUE"
        done
        # Calculate the CPU usage since we last checked.
        let "DIFF_IDLE=$IDLE-$PREV_IDLE"
        let "DIFF_TOTAL=$TOTAL-$PREV_TOTAL"
        let "DIFF_USAGE=(1000*($DIFF_TOTAL-$DIFF_IDLE)/$DIFF_TOTAL+5)/10"
        # Remember the total and idle CPU times for the next check.
        PREV_TOTAL="$TOTAL"
        PREV_IDLE="$IDLE"
        # CPU Model Name
        # ModelName=$(awk -F':' '/model name/ {print $2}' /proc/cpuinfo | sed 's/^[ \t]*//g')

        # Network traffic
        NET=($(grep ":" /proc/net/dev | grep -v -e "lo" -e "tun" | awk '{a+=$2}{b+=$10}END{print a,b}'))
        NetRx="${NET[0]}"
        NetTx="${NET[1]}"
        if [ "$PREV_NetRx" == "" ]; then
            PREV_NetRx="$NetRx"
            PREV_NetTx="$NetTx"
        fi
        let "SpeedRx=($NetRx-$PREV_NetRx)/$INTERVAL"
        let "SpeedTx=($NetTx-$PREV_NetTx)/$INTERVAL"
        PREV_NetRx="$NetRx"
        PREV_NetTx="$NetTx"

        # Bandwidth traffic monthly
        BandwidthRx="$NetRx"
        BandwidthTx="$NetTx"
        if [ "$PREV_BandwidthRx" == "" ]; then
            PREV_BandwidthRx="$NetRx"
            PREV_BandwidthTx="$NetTx"
        fi
        dHM=($(date +%d%H%M))
        if [ "$dHM" == "010000" ]; then
            PREV_BandwidthRx="$BandwidthRx"
            PREV_BandwidthTx="$BandwidthTx"
        fi
        let "BandwidthRx-=$PREV_BandwidthRx"
        let "BandwidthTx-=$PREV_BandwidthTx"

        # Service status
        NginxStatus=$(service nginx status | awk '/Active/ {print $2}')
        MysqlStatus=$(service mysql status | awk '/Active/ {print $2}')
        PhpFpmStatus=$(service php-fpm status | awk '/Active/ {print $2}')
        #GuacamoleStatus=$(service gucad status | awk '/Active/ {print $2}')

        #Update time
        Updated=$(date +%s)

        curl -X POST -H "Content-type:application/json" $UPDATE_URI -d '{ "server": {"name":"'$NAME'","type":"'$TYPE'","host":"'$HOST'","location":"'$LOCATION'", "online4":'$Online4', "online6":'$Online6', "uptime": "'$Uptime'", "load": '$Load', "memory_total": '$MemTotal', "memory_used": '$MemUsed', "swap_total": '$SwapTotal', "swap_used": '$SwapUsed', "hdd_total": '$HDDTotal', "hdd_used": '$HDDUsed', "cpu": '$DIFF_USAGE'.0, "network_rx": '$SpeedRx', "network_tx": '$SpeedTx', "bandwidth_rx": '$BandwidthRx', "bandwidth_tx": '$BandwidthTx', "custom": {"NGINX": "'$NginxStatus'", "MYSQL": "'$MysqlStatus'", "PHPFPM": "'$PhpFpmStatus'"}, "updated": '$Updated'}, "token": "'$TOKEN'" }'
    done

    wait
    if ! $RUNNING; then
        echo "Exiting"
        rm -f /tmp/fuckbash
        exit 0
    fi

    # keep on trying after a disconnect
    echo "Disconnected." >&2
    sleep 3
    echo "Reconnecting..." >&2
done
