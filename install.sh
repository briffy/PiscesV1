#!/bin/bash
systemctl stop nginx
systemctl disable nginx
apt-get remove nginx

rm -rf /var/dashboard
rm -rf /etc/monitor-scripts

systemctl disable bt-check.timer
systemctl disable bt-service-check.timer
systemctl disable clear-blockchain.timer
systemctl disable cpu-check.timer
systemctl disable external-ip-check.timer
systemctl disable fastsync-check.timer
systemctl disable gps-check.timer
systemctl disable helium-status-check.timer
systemctl disable infoheight-check.timer
systemctl disable local-ip-check.timer
systemctl disable miner-check.timer
systemctl disable miner-service-check.timer
systemctl disable miner-version-check.timer
systemctl disable password-check.timer
systemctl disable peer-list-check.timer
systemctl disable pf-check.timer
systemctl disable pf-service-check.timer
systemctl disable pubkeys-check.timer
systemctl disable reboot-check.timer
systemctl disable sn-check.timer
systemctl disable temp-check.timer
systemctl disable update-check.timer
systemctl disable update-dashboard-check.timer
systemctl disable update-miner-check.timer
systemctl disable wifi-check.timer
systemctl disable wifi-config-check.timer
systemctl disable wifi-service-check.timer

rm -rf /etc/systemd/system/bt-check.timer
rm -rf /etc/systemd/system/bt-service-check.service
rm -rf /etc/systemd/system/bt-service-check.timer
rm -rf /etc/systemd/system/clear-blockchain.timer
rm -rf /etc/systemd/system/clear-blockchain.service
rm -rf /etc/systemd/system/cpu-check.timer
rm -rf /etc/systemd/system/cpu-check.service
rm -rf /etc/systemd/system/external-ip-check.service
rm -rf /etc/systemd/system/external-ip-check.timer
rm -rf /etc/systemd/system/fastsync-check.service
rm -rf /etc/systemd/system/fastsync-check.timer
rm -rf /etc/systemd/system/gps-check.service
rm -rf /etc/systemd/system/gps-check.timer
rm -rf /etc/systemd/system/helium-status-check.service
rm -rf /etc/systemd/system/helium-status-check.timer
rm -rf /etc/systemd/system/infoheight-check.service
rm -rf /etc/systemd/system/infoheight-check.timer
rm -rf /etc/systemd/system/local-ip-check.service
rm -rf /etc/systemd/system/local-ip-check.timer
rm -rf /etc/systemd/system/miner-check.service
rm -rf /etc/systemd/system/miner-check.timer
rm -rf /etc/systemd/system/miner-service-check.service
rm -rf /etc/systemd/system/miner-service-check.timer
rm -rf /etc/systemd/system/miner-version-check.timer
rm -rf /etc/systemd/system/miner-version-check.service
rm -rf /etc/systemd/system/password-check.service
rm -rf /etc/systemd/system/password-check.timer
rm -rf /etc/systemd/system/peer-list-check.service
rm -rf /etc/systemd/system/peer-list-check.timer
rm -rf /etc/systemd/system/pf-check.service
rm -rf /etc/systemd/system/pf-check.timer
rm -rf /etc/systemd/system/pf-service-check.service
rm -rf /etc/systemd/system/pf-service-check.timer
rm -rf /etc/systemd/system/pubkeys-check.service
rm -rf /etc/systemd/system/pubkeys-check.timer
rm -rf /etc/systemd/system/reboot-check.service
rm -rf /etc/systemd/system/reboot-check.timer
rm -rf /etc/systemd/system/sn-check.service
rm -rf /etc/systemd/system/sn-check.timer
rm -rf /etc/systemd/system/temp-check.service
rm -rf /etc/systemd/system/temp-check.timer
rm -rf /etc/systemd/system/update-check.service
rm -rf /etc/systemd/system/update-check.timer
rm -rf /etc/systemd/system/update-dashboard-check.timer
rm -rf /etc/systemd/system/update-dashboard-check.service
rm -rf /etc/systemd/system/update-miner-check.timer
rm -rf /etc/systemd/system/update-miner-check.service
rm -rf /etc/systemd/system/wifi-check.service
rm -rf /etc/systemd/system/wifi-check.timer
rm -rf /etc/systemd/system/wifi-config-check.service
rm -rf /etc/systemd/system/wifi-config-check.timer
rm -rf /etc/systemd/system/wifi-service-check.service
rm -rf /etc/systemd/system/wifi-service-check.timer

systemctl daemon-reload

mkdir /home/pi/dashboard
mkdir /home/pi/configs
mkdir /home/pi/database

chown -R root:root /home/pi/dashboard
chmod -R 775 /home/pi/dashboard

wget https://raw.githubusercontent.com/briffy/PiscesV1/main/watchdog.sh -O /home/pi/dashboard/watchdog.sh
wget https://raw.githubusercontent.com/briffy/PiscesV1/main/dashboard-watchdog.service -O /etc/systemd/system/dashboard-watchdog.service
wget https://raw.githubusercontent.com/briffy/PiscesV1/main/dashboard-watchdog.timer -O /etc/systemd/system/dashboard-watchdog.timer

docker run -d --init --ulimit nofile=64000:64000 --restart always --publish 80:80/tcp --publish 443:443/tcp --publish 127.0.0.1:3306:3306/tcp --name dashboard --mount type=bind,source=/home/pi/dashboard/logs,target=/var/dashboard/external/logs --mount type=bind,source=/home/pi/dashboard/configs,target=/var/dashboard/external --mount type=bind,source=/home/pi/dashboard/database,target=/var/dashboard/database --mount type=bind,source=/home/pi/hnt/miner/log,target=/var/dashboard/miner-logs ghcr.io/briffy/piscesv1:latest

systemctl enable dashboard-watchdog.timer
systemctl start dashboard-watchdog.service
