#!/bin/bash
db_passwd=$(cat /home/pi/dashboard/configs/db_passwd | tr -d '\n')
database=$(echo "mysql --user=admin --password="$db_passwd" --host 127.0.0.1 dashboard -s")

timestamp=$(date +%s)

miner_update_lastupdated=$(echo "SELECT last_updated FROM updates WHERE name = 'miner';" | $database)
dashboard_update_lastupdated=$(echo "SELECT last_updated FROM updates WHERE name = 'dashboard';" | $database)
bt_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'BT';" | $database)
pf_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'PF';" | $database)
wifi_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'WiFi';" | $database)
wifi_service_state=$(echo "SELECT status FROM services WHERE name = 'WiFi';" | $database)
automaintain_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'AutoMaintain';" | $database)
autoupdate_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'AutoUpdate';" | $database)
fastsync_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'FastSync';" | $database)
clearblockchain_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'ClearBlockchain';" | $database)
minerupdate_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'MinerUpdate';" | $database)
dashboardupdate_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'DashboardUpdate';" | $database)
miner_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'miner';" | $database)
automaintain_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'AutoMaintain';" | $database)
autoupdate_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'AutoUpdate';" | $database)
reboot_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'reboot';" | $database)
reboot_service_lastupdated=$(echo "SELECT last_updated FROM services WHERE name = 'reboot';" | $database)

info_height_lastupdated=$(echo "SELECT last_updated FROM stats WHERE name = 'info_height'" | $database)
live_height_lastupdated=$(echo "SELECT last_updated FROM stats WHERE name = 'live_height'" | $database)
pubkey_lastupdated=$(echo "SELECT last_updated FROM stats WHERE name = 'pubkey'" | $database)
pubkey_value=$(echo "SELECT value FROM stats WHERE name = 'pubkey'" | $database)
animal_name_lastupdated=$(echo "SELECT last_updated FROM stats WHERE name = 'animal_name'" | $database)
animal_name_value=$(echo "SELECT value FROM stats WHERE name = 'animal_name'" | $database)
serial_number_lastupdated=$(echo "SELECT last_updated FROM stats WHERE name = 'serial_number'" | $database)
serial_number_value=$(echo "SELECT value FROM stats WHERE name = 'serial_number'" | $database)
online_status_lastupdated=$(echo "SELECT last_updated FROM stats WHERE name = 'online_status'" | $database)
eth_ip_lastupdated=$(echo "SELECT last_updated FROM stats WHERE name = 'eth_ip'" | $database)
wlan_ip_lastupdated=$(echo "SELECT last_updated FROM stats WHERE name = 'wlan_ip'" | $database)
remote_ip_lastupdated=$(echo "SELECT last_updated FROM stats WHERE name = 'remote_ip'" | $database)

wifi_config=$(echo "SELECT status FROM wifi WHERE ID = 1" | $database)

if test -f /home/pi/dashboard/configs/password; then
  password=$(</home/pi/dashboard/configs/password)
  echo 'admin:'$password | chpasswd
  rm /home/pi/dashboard/configs/password
fi

if [[ $wifi_config == "newconfig" ]]; then
  wifi_ssid=$(echo "SELECT SSID FROM wifi WHERE ID = 1" | $database)
  wifi_psk=$(echo "SELECT PSK FROM wifi WHERE ID = 1" | $database)
  wifi_location=$(echo "SELECT location FROM wifi WHERE ID = 1" | $database)

  sed "s/:SSID/$wifi_ssid/g;s/:PSK/$wifi_psk/g;s/:location/$wifi_location/g" /home/pi/dashboard/configs/wifi_template.conf > /etc/wpa_supplicant/wpa_supplicant.conf

  echo "UPDATE wifi SET status = 'applied' WHERE ID = 1" | $database
  echo "UPDATE services SET status = 'on', enabled = 1, time_started = $timestamp WHERE name = 'WiFi';" | $database
fi

if [[ $automaintain_service_enabled -eq 1 ]]; then
  echo "UPDATE services SET status = 'on', enabled = 1, time_started = $timestamp WHERE name = 'AutoMaintain';" | $database
fi

if [[ $automaintain_service_enabled -eq 0 ]]; then
  echo "UPDATE services SET status = 'off', enabled = 0 WHERE name = 'AutoMaintain';" | $database
fi

if [[ $autoupdate_service_enabled -eq 1 ]]; then
  echo "UPDATE services SET status = 'on', enabled = 1, time_started = $timestamp WHERE name = 'AutoUpdate';" | $database
fi

if [[ $autoupdate_service_enabled -eq 0 ]]; then
  echo "UPDATE services SET status = 'off', enabled = 0 WHERE name = 'AutoUpdate';" | $database
fi

if [[ $((timestamp - info_height_lastupdated)) -ge 60 ]]; then
  info_height=$(docker exec miner miner info height | grep -Po '[ \t]+[0-9]*' | sed 's/\t\t//')
  echo "UPDATE stats SET value = '$info_height', last_updated = '$timestamp' WHERE name = 'info_height';" | $database
fi

if [[ $((timestamp - live_height_lastupdated)) -ge 60 ]]; then
  live_height=$(wget -qO- 'https://api.helium.io/v1/blocks/height' | grep -Po '"height":[^}]+' | sed -e 's/^"height"://')
  echo "UPDATE stats SET value = '$live_height', last_updated = '$timestamp' WHERE name = 'live_height';" | $database
fi

if [[ $((timestamp - pubkey_lastupdated)) -ge 28800 || $pubkey_value == "" ]]; then
  data=$(docker exec miner miner print_keys)

  if [[ $data =~ animal_name,\"([^\"]*) ]]; then
    match="${BASH_REMATCH[1]}"
  fi

  animal_name=$(echo "${match//-/ }")

  if [[ $data =~ pubkey,\"([^\"]*) ]]; then
    pubkey="${BASH_REMATCH[1]}"
  fi

  if [[ $pubkey != "" ]]; then
    echo "UPDATE stats SET value = '$pubkey', last_updated = '$timestamp' WHERE name = 'pubkey';" | $database
  fi

  if [[ $animal_name != "" ]]; then
    echo "UPDATE stats SET value = '$animal_name', last_updated = '$timestamp' WHERE name = 'animal_name';" | $database
  fi
fi

if [[ $((timestamp - serial_number_lastupdated)) -ge 28800 || $serial_number_value == "" ]]; then
  sn=$(curl -s 'http://localhost:8001/api/test/minerSn/read' | grep -Po '"minerSn":[^\,]+' | sed -e 's/^"minerSn"://' | tr -d '"' | tr -d ' ') 
  echo "UPDATE stats SET value = '$sn', last_updated = '$timestamp' WHERE name = 'serial_number';" | $database
fi

if [[ $((timestamp - online_status_lastupdated)) -ge 60 ]] && [[ $pubkey ]]; then
  root_uri='https://api.helium.io/v1/hotspots/'
  activity_uri="/activity"
  uri="$root_uri$pubkey"
  recent_activity_uri="$uri$activity_uri"

  data=$(wget -qO- $uri)
  online_status=$(echo $data | grep -Po '"online":".*?[^\\]"' | sed -e 's/^"online"://' | tr -d '"')
  echo "UPDATE stats SET value = '$online_status', last_updated = '$timestamp' WHERE name = 'online_status';" | $database
fi

if [[ $((timestamp - eth_ip_lastupdated)) -ge 3600 ]]; then
  ethernet=$(ip address show eth0 | grep "inet " | egrep -o "inet [^.]+.[^.]+.[^.]+.[^/]+" | sed -e "s/inet //") 
  echo "UPDATE stats SET value = '$ethernet', last_updated = '$timestamp' WHERE name = 'eth_ip';" | $database
fi

if [[ $((timestamp - remote_ip_lastupdated)) -ge 28800 ]]; then
  remote_ip=$(curl -4 icanhazip.com)
  echo "UPDATE stats SET value = '$remote_ip', last_updated = '$timestamp' WHERE name = 'remote_ip';" | $database
fi

if [[ $((timestamp - wlan_ip_lastupdated)) -ge 3600 && wifi_service_state == 'on' ]]; then
  wlan=$(ip address show wlan0 | grep "inet " | egrep -o "inet [^.]+.[^.]+.[^.]+.[^/]+" | sed -e "s/inet //") 
  echo "UPDATE stats SET value = '$wlan', last_updated = '$timestamp' WHERE name = 'wlan_ip';" | $database
fi

if [[ $((timestamp - miner_update_lastupdated)) -ge 1 ]]; then
  miner_update=$(echo "SELECT latest_version FROM updates WHERE name = 'miner';" | $database)
  currentversion=$(echo "SELECT current_version FROM updates WHERE name = 'miner';" | $database)

  if [[ ! $currentversion ]]; then
    currentversion=$(docker ps -a -f name=miner --format "{{ .Image }}" | grep -Po 'miner: *.+' | sed 's/miner://')
    echo "UPDATE updates SET current_version = '$currentversion' WHERE name ='miner';" | $database
  fi

  latest_version=$(curl -s https://quay.io/api/v1/repository/team-helium/miner | grep -Po 'miner-arm64_[0-9]+\.[0-9]+\.[0-9]+\.[^"]+_GA' | sort -n | tail -1)

  if [[ $miner_update != $latest_version ]]; then
    echo "UPDATE updates SET latest_version = '$latest_version' WHERE name = 'miner';" | $database
  fi

  echo "UPDATE updates SET last_updated = '$timestamp' WHERE name = 'miner';" | $database
fi

if [[ $((timestamp - dashboard_update_lastupdated)) -ge 3600 ]]; then
  dashboard_update=$(echo "SELECT latest_version FROM updates WHERE name = 'dashboard';"  | $database | tr -d "v" | tr -d ".")

  latest_version=$(wget --no-cache https://raw.githubusercontent.com/briffy/PiscesV1/main/version -qO-)
  latest_version_stripped=$(echo $latest_version | tr -d "v" | tr -d ".")

  if [[ $latest_version_stripped > $dashboard_update ]]; then
    echo "UPDATE updates SET latest_version = '$latest_version' WHERE name = 'dashboard';" | $database
  fi

  echo "UPDATE updates SET last_updated = '$timestamp' WHERE name = 'dashboard';" | $database
fi

if [[ $((timestamp - bt_service_lastupdated)) -ge 15 ]]; then
  bt_service_state=$(echo "SELECT status FROM services WHERE name = 'BT';" | $database)
  bt_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'BT';" | $database)

  if [[ $bt_service_enabled -eq 1 ]]; then
    if [[ $bt_service_state == 'start' ]]; then
      sudo /home/pi/config/_build/prod/rel/gateway_config/bin/gateway_config advertise on
      echo "UPDATE services SET status = 'starting' WHERE name = 'BT';" | $database
    fi

    if [[ $bt_service_state == 'starting' ]]; then
      advertise_status=$(sudo /home/pi/config/_build/prod/rel/gateway_config/bin/gateway_config advertise status)
      if [[ $advertise_status == 'on' ]]; then
        echo "UPDATE services SET status = 'on' WHERE name = 'BT';" | $database
      fi
    fi

    if [[ $bt_service_state == 'stop' ]]; then
      sudo /home/pi/config/_build/prod/rel/gateway_config/bin/gateway_config advertise off
      echo "UPDATE services SET status = 'stopping' WHERE name = 'BT';" | $database
    fi

    if [[ $bt_service_state == 'stopping' ]]; then
      advertise_status=$(sudo /home/pi/config/_build/prod/rel/gateway_config/bin/gateway_config advertise status)
      if [[ $advertise_status == 'off' || $advertise_status == "" ]]; then
        echo "UPDATE services SET status = 'off', enabled = 0 WHERE name = 'BT';" | $database
      fi
    fi
  fi
  echo "UPDATE services SET last_updated = '$timestamp' WHERE name = 'BT';" | $database
fi

if [[ $((timestamp - pf_service_lastupdated)) -ge 15 ]]; then
  pf_service_state=$(echo "SELECT status FROM services WHERE name = 'PF';" | $database)
  pf_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'PF';" | $database)

  if [[ $pf_service_enabled -eq 1 ]]; then
    status=$(systemctl show -p SubState --value lora_pkt_fwd)

    if [[ ! $pf_service_state == 'on' ]]; then
      systemctl stop lora_pkt_fwd
      systemctl start lora_pkt_fwd
      echo "UPDATE services SET status = 'starting', time_started = $timestamp WHERE name = 'PF';" | $database
    fi

    if [[ $pf_service_state == 'starting' ]]; then
      if [[ $status == 'running' ]]; then
        echo "UPDATE services SET status = 'on' WHERE name = 'PF';" | $database
      else
        time_started=$(echo "SELECT time_started FROM services WHERE name = 'PF';" | $database)

        if [[ $((timestamp - time_started)) -ge 120 ]]; then
          systemctl stop lora_pkt_fwd
          systemctl start lora_pkt_fwd
          echo "UPDATE services SET time_started = $timestamp WHERE name = 'PF';" | $database
        fi
      fi
    fi

    if [[ $pf_service_state == 'stop' ]]; then
      systemctl stop lora_pkt_fwd
      echo "UPDATE services SET status = 'stopping' WHERE name = 'PF';" | $database
    fi

    if [[ $pf_service_state == 'stopping' ]]; then
      if [[ $status != 'running' ]]; then
        echo "UPDATE services SET status = 'off', enabled = 0 WHERE name = 'PF';" | $database
      fi
    fi
  elif [[ $pf_service_enabled -eq 0 ]]; then
    if [[ $pf_service_status != 'off' ]]; then
      systemctl stop lora_pkt_fwd
    fi
  fi

  status=$(systemctl show -p SubState --value lora_pkt_fwd)
  if [[ $status != 'running' ]]; then
    echo "UPDATE services SET status = 'off' WHERE name = 'PF';" | $database
  fi

  echo "UPDATE services SET last_updated = '$timestamp' WHERE name = 'PF';" | $database
fi

if [[ $((timestamp - wifi_service_lastupdated)) -ge 15 ]]; then
  wifi_service_state=$(echo "SELECT status FROM services WHERE name = 'WiFi';" | $database)
  wifi_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'WiFi';" | $database)

  if [[ $wifi_service_enabled -eq 1 ]]; then
    status=$(ip -o -4 addr list wlan0 | awk '{print $4}' | cut -d/ -f1)

    if [[ $wifi_service_state == 'start' || $wifi_service_state == 'off' ]]; then
      rfkill unblock 0
      ip link set wlan0 up
      echo "UPDATE services SET status = 'starting', time_started = $timestamp WHERE name = 'WiFi';" | $database
    fi

    if [[ $wifi_service_state == 'starting' ]]; then
      if [[ $status ]]; then
        echo "UPDATE services SET status = 'on' WHERE name = 'WiFi';" | $database
      else
        time_started=$(echo "SELECT time_started FROM services WHERE name = 'WiFi';" | $database)

        if [[ $((timestamp - time_started)) -ge 120 ]]; then
          ip link set wlan0 up
          echo "UPDATE services SET time_started = $timestamp WHERE name = 'WiFi';" | $database
        fi
      fi
    fi

    if [[ $wifi_service_state == 'stop' ]]; then
      ip link set wlan0 down
      echo "UPDATE services SET status = 'stopping' WHERE name = 'WiFi';" | $database
    fi

    if [[ $wifi_service_state == 'stopping' ]]; then
      if [[ ! $status ]]; then
        echo "UPDATE services SET status = 'off', enabled = 0 WHERE name = 'WiFi';" | $database
      fi
    fi
  else
    if [[ $wifi_service_status != 'off' ]]; then
      ip link set wlan0 down
    fi
  fi

  status=$(ip -o -4 addr list wlan0 | awk '{print $4}' | cut -d/ -f1)
  if [[ ! $status ]]; then
    echo "UPDATE services SET status = 'off' WHERE name = 'WiFi';" | $database
  fi

  echo "UPDATE services SET last_updated = '$timestamp' WHERE name = 'WiFi';" | $database
fi

if [[ $((timestamp - automaintain_service_lastupdated)) -ge 3600 ]]; then
  if [[ $automaintain_service_enabled -eq 1 ]]; then

    current_docker_status=$(sudo docker ps -a -f name=miner --format "{{ .Status }}")

    if [[ ! $current_docker_status =~ 'Up' ]]; then
      echo "[$(date)] Problems with docker, trying to start..." >> /home/pi/dashboard/logs/AutoMaintain.log
      docker start miner
      sleep 1m
      current_docker_status=$(sudo docker ps -a -f name=miner --format "{{ .Status }}")
      uptime=$(sudo docker ps -a -f name=miner --format "{{ .Status }}" | grep -Po "Up [0-9]* seconds" | sed 's/ seconds//' | sed 's/Up //')

      if [[ ! $current_docker_status =~ 'Up' ]] || [[ $uptime != '' && $uptime -le 55 ]]; then
        echo "[$(date)] Still problems with docker, trying a miner update..." >> /home/pi/dashboard/logs/AutoMaintain.log
        echo '[$(date)] Stopping currently running docker...' > /home/pi/dashboard/logs/AutoMaintain.log
        docker stop miner >> /home/pi/dashboard/logs/AutoMaintain.log
        currentdockerstatus=$(sudo docker ps -a -f name=miner --format "{{ .Status }}")
        if [[ $currentdockerstatus =~ 'Exited' || $currentdockerstatus == '' ]]; then
          version=$(echo "SELECT latest_version FROM updates WHERE name = 'miner';")
          echo '[$(date)] Backing up current config...' >> /home/pi/dashboard/logs/AutoMaintain.log
          currentconfig=$(sudo docker inspect miner | grep sys.config | grep -Po '"Source": ".*\/sys.config' | sed 's/"Source": "//' | sed -n '1p')
          mkdir /home/pi/hnt/miner/configs
          mkdir /home/pi/hnt/miner/configs/previous_configs
          currentversion=$(docker ps -a -f name=miner --format "{{ .Image }}" | grep -Po 'miner: *.+' | sed 's/miner://')
          cp "$currentconfig" "/home/pi/hnt/miner/configs/previous_configs/$currentversion.config" >> /home/pi/dashboard/logs/AutoMaintain.log
          echo '[$(date)] Acquiring latest Helium config from GitHub...' >> /home/pi/dashboard/logs/AutoMaintain.log
          wget https://raw.githubusercontent.com/briffy/PiscesQoLDashboard/main/sys.config -O /home/pi/hnt/miner/configs/sys.config >> /home/pi/dashboard/logs/AutoMaintain.log
          echo '[$(date)] Removing currently running docker...' >> /home/pi/dashboard/logs/AutoMaintain.log
          docker rm miner
          echo '[$(date)] Acquiring and starting latest docker version...' >> /home/pi/dashboard/logs/AutoMaintain.log
          docker image pull quay.io/team-helium/miner:$version >> /home/pi/dashboard/logs/AutoMaintain.log
          docker run -d --init --ulimit nofile=64000:64000 --restart always --publish 127.0.0.1:1680:1680/udp --publish 44158:44158/tcp --publish 127.0.0.1:4467:4467/tcp --name miner --mount type=bind,source=/home/pi/hnt/miner,target=/var/data --mount type=bind,source=/home/pi/hnt/miner/log,target=/var/log/miner --device /dev/i2c-0  --privileged -v /var/run/dbus:/var/run/dbus --mount type=bind,source=/home/pi/hnt/miner/configs/sys.config,target=/config/sys.config quay.io/team-helium/miner:$version >> /home/pi/dashboard/logs/AutoMaintain.log
        fi

        current_docker_status=$(sudo docker ps -a -f name=miner --format "{{ .Status }}")
        if [[ ! $current_docker_status =~ 'Up' || $uptime != '' && $uptime -le 55 ]]; then
          echo "[$(date)] STILL problems with docker, trying a blockchain clear..." >> /home/pi/dashboard/logs/AutoMaintain.log
          docker kill miner >> /home/pi/dashboard/logs/AutoMaintain.log
          sleep 10
          currentdockerstatus=$(sudo docker ps -a -f name=miner --format "{{ .Status }}")

          if [[ ! $currentdockerstatus =~ 'Up' || $currentdockerstatus == '' ]]; then
            echo '[$(date)] Clearing Blockchain folders...' >> /home/pi/dashboard/logs/AutoMaintain.log
            for f in /home/pi/hnt/miner/blockchain.db/*;
            do
              rm -rfv "$f"
            done

            for f in /home/pi/hnt/miner/ledger.db/*;
            do
              rm -rfv "$f"
            done
            echo '[$(date)] Finished clearing Blockchain folders...' >> /home/pi/dashboard/logs/AutoMaintain.log
          fi
          echo '[$(date)] Starting miner...' >> /home/pi/dashboard/logs/AutoMaintain.log
          docker start miner
        fi
      fi
    fi

    info_height=$(echo "SELECT value FROM stats WHERE name = 'info_height';" | $database)
    live_height=$(echo "SELECT value FROM stats WHERE name = 'live_height';" | $database)
    snap_height=$(wget -q https://helium-snapshots.nebra.com/latest.json -O - | grep -Po '\"height\": [0-9]*' | sed 's/\"height\": //')

    if [[ $info_height ]] && [[ $live_height ]]; then
      if [[ $((live_height - info_height)) -ge 500 ]]; then
        if [[ $snap_height ]]; then
          echo "[$(date)] Big difference in blockheight, doing a fast sync..." >> /home/pi/dashboard/logs/AutoMaintain.log
          wget https://helium-snapshots.nebra.com/snap-$snap_height -O /home/pi/hnt/miner/snap/snap-latest
          docker exec miner miner repair sync_pause
          docker exec miner miner repair sync_cancel
          docker exec miner miner snapshot load /var/data/snap/snap-latest
          sleep 2m
          sync_state=$(docker exec miner miner repair sync_state)

          if [[ $sync_state != 'sync active' ]]; then
            docker exec miner miner repair sync_resume
          else
            sleep 2m
            docker exec miner miner repair sync_resume
          fi
        fi
      fi
    fi

    disk_usage=$(df --output=pcent / | tr -dc '0-9')

    if [[ $disk_usage -ge 70 ]]; then
      echo "[$(date)] High disk usage, doing a Blockchain clear..." >> /home/pi/dashboard/logs/AutoMaintain.log
      docker kill miner >> /home/pi/dashboard/logs/AutoMaintain.log
      sleep 10
      currentdockerstatus=$(sudo docker ps -a -f name=miner --format "{{ .Status }}")

      if [[ ! $currentdockerstatus =~ 'Up' || $currentdockerstatus == '' ]]; then
        echo '[$(date)] Clearing Blockchain folders...' >> /home/pi/dashboard/logs/AutoMaintain.log
        for f in /home/pi/hnt/miner/blockchain.db/*;
        do
          rm -rfv "$f"
        done

        for f in /home/pi/hnt/miner/ledger.db/*;
        do
          rm -rfv "$f"
        done
        echo '[$(date)] Finished clearing Blockchain folders...' >> /home/pi/dashboard/logs/AutoMaintain.log
      fi
      echo '[$(date)] Starting miner...' >> /home/pi/dashboard/logs/AutoMaintain.log
      docker start miner
    fi

    pubkey=$(echo "SElECT value FROM stats WHERE name = 'pubkey';" | $database)

    if [[ ! $pubkey ]]; then
      echo "[$(date)] Your public key is missing, trying a refresh..." >> /home/pi/dashboard/logs/AutoMaintain.log
      data=$(docker exec miner miner print_keys)

      if [[ $data =~ pubkey,\"([^\"]*) ]]; then
        pubkey="${BASH_REMATCH[1]}"
      fi

      echo "UPDATE stats SET value = '$pubkey', last_updated = '$timestamp' WHERE name = 'pubkey';" | $database

    fi
  fi

  echo "UPDATE services SET last_updated = '$timestamp' WHERE name = 'AutoMaintain';" | $database
fi

if [[ $((timestamp - autoupdate_service_lastupdated)) -ge 3600  ]]; then
  if [[ $autoupdate_service_enabled -eq 1 ]]; then
    miner_version=$(echo "SELECT current_version FROM updates WHERE name = 'miner';" | $database)
    latest_miner_version=$(echo "SELECT latest_version FROM updates WHERE name = 'miner';" | $database)

    if [[ $miner_version ]] && [[ $latest_miner_version ]]; then
      if [[ $miner_version != $latest_miner_version ]]; then
        echo "[$(date)] Miner is out of date, trying a miner update..." >> /home/pi/dashboard/logs/AutoMaintain.log
        echo "UPDATE services SET enabled = 1, status = 'start' WHERE name = 'MinerUpdate';" | $database
      fi
    fi
  fi

  echo "UPDATE services SET last_updated = '$timestamp' WHERE name = 'AutoUpdate';" | $database
fi

if [[ $((timestamp - miner_service_lastupdated)) -ge 15 ]]; then
  miner_service_state=$(echo "SELECT status FROM services WHERE name = 'miner';" | $database)
  miner_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'miner';" | $database)
  status=$(sudo docker inspect --format "{{.State.Running}}" miner)
  if [[ $miner_service_enabled -eq 1 ]]; then
    if [[ ! $miner_service_state == 'on' ]]; then
      docker start miner
      echo "UPDATE services SET status = 'starting', time_started = $timestamp WHERE name = 'miner';" | $database
    fi

    if [[ $miner_service_state == 'starting' ]]; then
      if [[ $status == "true" ]]; then
        echo "UPDATE services SET status = 'on' WHERE name = 'miner';" | $database
      else
        time_started=$(echo "SELECT time_started FROM services WHERE name = 'miner';" | $database)

        if [[ $((timestamp - time_started)) -ge 120 ]]; then
          docker start miner
          echo "UPDATE services SET time_started = $timestamp WHERE name = 'miner';" | $database
        fi
      fi
    fi
  elif [[ $miner_service_enabled -eq 0 ]]; then
    if [[ $miner_service_state == 'stop' ]]; then
        echo "UPDATE services SET status = 'stopping' WHERE name = 'miner';" | $database
        docker stop miner
    fi

    if [[ $miner_service_state == 'stopping' ]]; then
      if [[ $status == "false" ]]; then
        echo "UPDATE services SET status = 'off', enabled = 0 WHERE name = 'miner';" | $database
      fi
    fi

    if [[ $miner_service_status != 'off' ]]; then
      docker stop miner
    fi
  fi

  status=$(docker inspect --format "{{.State.Running}}" miner)
  if [[ $status == "false" ]]; then
    echo "UPDATE services SET status = 'off' WHERE name = 'miner';" | $database
  fi

  echo "UPDATE services SET last_updated = '$timestamp' WHERE name = 'miner';" | $database
fi


if [[ $((timestamp - fastsync_service_lastupdated)) -ge 15 ]]; then
  fastsync_service_state=$(echo "SELECT status FROM services WHERE name = 'FastSync';" | $database)
  fastsync_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'FastSync';" | $database)
  status=$(docker exec miner miner repair sync_state)
  if [[ $fastsync_service_enabled -eq 1 ]]; then
    if [[ $fastsync_service_state == 'start' || $fastsync_service_state == 'off' ]]; then
      echo "UPDATE services SET status = 'starting', time_started = $timestamp WHERE name = 'FastSync';" | $database
      echo '' > /home/pi/dashboard/logs/FastSync.log
      snap_height=$(wget -q https://helium-snapshots.nebra.com/latest.json -O - | grep -Po '\"height\": [0-9]*' | sed 's/\"height\": //')
      wget https://helium-snapshots.nebra.com/snap-$snap_height -O /home/pi/hnt/miner/snap/snap-latest 2>&1 | tee -a /home/pi/dashboard/logs/FastSync.log
      docker exec miner miner repair sync_pause
      docker exec miner miner repair sync_cancel
      docker exec miner miner snapshot load /var/data/snap/snap-latest >> /home/pi/dashboard/logs/FastSync.log
    fi

    if [[ $fastsync_service_state == 'starting' && $status != 'active' ]]; then
      docker exec miner miner repair sync_resume
      echo "UPDATE services SET status = 'finished', enabled = 0 WHERE name = 'FastSync';" | $database
    fi
  fi

  echo "UPDATE services SET last_updated = '$timestamp' WHERE name = 'FastSync';" | $database
fi

if [[ $((timestamp - clearblockchain_service_lastupdated)) -ge 15 ]]; then
  clearblockchain_service_state=$(echo "SELECT status FROM services WHERE name = 'ClearBlockchain';" | $database)
  clearblockchain_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'ClearBlockchain';" | $database)

  status=$(docker ps -a -f name=miner --format "{{ .Status }}")
  if [[ $clearblockchain_service_enabled -eq 1 ]]; then
    if [[ $clearblockchain_service_state == 'start' || $clearblockchain_service_state == 'off' ]]; then
      echo "UPDATE services SET status = 'starting', time_started = $timestamp WHERE name = 'ClearBlockchain';" | $database
      echo '' > /home/pi/dashboard/logs/ClearBlockchain.log
      docker kill miner >> /home/pi/dashboard/logs/ClearBlockchain.log
      sleep 10
      currentdockerstatus=$(sudo docker ps -a -f name=miner --format "{{ .Status }}")

      if [[ ! $currentdockerstatus =~ 'Up' || $currentdockerstatus == '' ]]; then
        echo 'Clearing Blockchain folders...' >> /home/pi/dashboard/logs/ClearBlockchain.log
        for f in /home/pi/hnt/miner/blockchain.db/*;
        do
          rm -rfv "$f" >> /home/pi/dashboard/logs/ClearBlockchain.log
        done

        for f in /home/pi/hnt/miner/ledger.db/*;
        do
          rm -rfv "$f" >> /home/pi/dashboard/logs/ClearBlockchain.log
        done
      fi
      docker start miner
      sleep 10
      currentdockerstatus=$(sudo docker ps -a -f name=miner --format "{{ .Status }}")
      if [[ $currentdockerstatus =~ 'Up' ]]; then
        echo "UPDATE services SET status = 'finished', time_started = $timestamp WHERE name = 'ClearBlockchain';" | $database
      else
        echo "UPDATE services SET status = 'finished-error', time_started = $timestamp WHERE name = 'ClearBlockchain';" | $database
      fi
    fi
  fi
  echo "UPDATE services SET last_updated = '$timestamp' WHERE name = 'ClearBlockchain';" | $database
fi

if [[ $((timestamp - minerupdate_service_lastupdated)) -ge 15 ]]; then
  minerupdate_service_state=$(echo "SELECT status FROM services WHERE name = 'MinerUpdate';" | $database)
  minerupdate_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'MinerUpdate';" | $database)
  if [[ $minerupdate_service_enabled -eq 1 ]]; then
    if [[ $minerupdate_service_state == 'start' || $minerupdate_service_state == 'off' ]]; then
      echo "UPDATE services SET status = 'starting', time_started = $timestamp WHERE name = 'MinerUpdate';" | $database
      echo 'Stopping currently running docker...' > /home/pi/dashboard/logs/MinerUpdate.log
      docker stop miner >> /home/pi/dashboard/logs/MinerUpdate.log
      currentdockerstatus=$(sudo docker ps -a -f name=miner --format "{{ .Status }}")
      if [[ $currentdockerstatus =~ 'Exited' || $currentdockerstatus == '' ]]; then
        version=$(echo "SELECT latest_version FROM updates WHERE name = 'miner';" | $database)
        echo 'Backing up current config...' >> /home/pi/dashboard/logs/MinerUpdate.log
        currentconfig=$(sudo docker inspect miner | grep sys.config | grep -Po '"Source": ".*\/sys.config' | sed 's/"Source": "//' | sed -n '1p')
        mkdir /home/pi/hnt/miner/configs
        mkdir /home/pi/hnt/miner/configs/previous_configs
        currentversion=$(docker ps -a -f name=miner --format "{{ .Image }}" | grep -Po 'miner: *.+' | sed 's/miner://')
        cp "$currentconfig" "/home/pi/hnt/miner/configs/previous_configs/$currentversion.config" >> /home/pi/dashboard/logs/MinerUpdate.log
        echo 'Acquiring latest Helium config from GitHub...' >> /home/pi/dashboard/logs/MinerUpdate.log
        wget https://raw.githubusercontent.com/briffy/PiscesQoLDashboard/main/sys.config -O /home/pi/hnt/miner/configs/sys.config >> /home/pi/dashboard/logs/MinerUpdate.log
        echo 'Removing currently running docker...' >> /home/pi/dashboard/logs/MinerUpdate.log
        docker rm miner
        echo 'Acquiring and starting latest docker version...' >> /home/pi/dashboard/logs/MinerUpdate.log
        docker image pull quay.io/team-helium/miner:$version >> /home/pi/dashboard/logs/MinerUpdate.log
        docker run -d --init --ulimit nofile=64000:64000 --restart always --publish 127.0.0.1:1680:1680/udp --publish 44158:44158/tcp --publish 127.0.0.1:4467:4467/tcp --name miner --mount type=bind,source=/home/pi/hnt/miner,target=/var/data --mount type=bind,source=/home/pi/hnt/miner/log,target=/var/log/miner --device /dev/i2c-0  --privileged -v /var/run/dbus:/var/run/dbus --mount type=bind,source=/home/pi/hnt/miner/configs/sys.config,target=/config/sys.config quay.io/team-helium/miner:$version >> /home/pi/dashboard/logs/MinerUpdate.log

        currentdockerstatus=$(sudo docker ps -a -f name=miner --format "{{ .Status }}")
        if [[ $currentdockerstatus =~ 'Up' ]]; then
          echo 'Removing old docker firmware image to save space ...' >> /home/pi/dashboard/logs/MinerUpdate.log
          docker rmi $(docker images -q quay.io/team-helium/miner:$currentversion)
          echo "DISTRIB_RELEASE=$(echo $version | sed -e 's/miner-arm64_//' | sed -e 's/_GA//')" > /etc/lsb_release
          echo 'Update complete.' >> /home/pi/dashboard/logs/MinerUpdate.log
          echo "UPDATE updates SET current_version = '$version' WHERE name = 'miner';" | $database
          echo "UPDATE services SET status = 'finished' WHERE name = 'MinerUpdate';" | $database
        else
          echo "UPDATE services SET status = 'finished-error' WHERE name = 'MinerUpdate';" | $database
          echo 'Miner docker failed to start.  Check logs to investigate.' >> /home/pi/dashboard/logs/MinerUpdate.log
        fi
      else
        echo "UPDATE services SET status = 'finished-error' WHERE name = 'MinerUpdate';" | $database
        echo 'Error: Could not stop docker.' >> /home/pi/dashboard/logs/MinerUpdate.log
      fi
    fi
  fi

  echo "UPDATE services SET last_updated = '$timestamp' WHERE name = 'MinerUpdate';" | $database
fi

if [[ $((timestamp - dashboardupdate_service_lastupdated)) -ge 15 ]]; then
  dashboardupdate_service_state=$(echo "SELECT status FROM services WHERE name = 'DashboardUpdate';" | $database)
  dashboardupdate_service_enabled=$(echo "SELECT enabled FROM services WHERE name = 'DashboardUpdate';" | $database)
fi

if [[ $((timestamp - reboot_service_lastupdated)) -ge 15  ]]; then
  if [[ $reboot_service_enabled -eq 1 ]]; then
    echo "UPDATE services SET enabled = 0, status = 'off' WHERE name = 'reboot';" | $database
    reboot
  fi

  echo "UPDATE services SET last_updated = '$timestamp' WHERE name = 'reboot';" | $databasesu
fi
