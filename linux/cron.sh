#!/bin/bash

mkdir ~/cron
mkdir ~/cron/cron.d
mkdir ~/cron/var_spool_cron/
mkdir ~/cron/var_spool_at/
mkdir ~/cron/cron_timed

sudo cp -r /etc/cron.d/* ~/cron/cron.d/
sudo cp -r /var/spool/cron/* ~/cron/var_spool_cron/
sudo cp -r /var/spool/at/* ~/cron/var_spool_at/
sudo cp -r /etc/cron.{daily,weekly,hourly,monthly} ~/cron/cron_timed/
sudo cp -r /etc/{crontab,anacrontab} ~/cron/cron_timed

sudo rm -rf /etc/cron.d/*
sudo rm -rf /var/spool/cron/*
sudo rm -rf /var/spool/at/*
sudo rm -rf /etc/cron.{daily,weekly,hourly,monthly}
sudo rm -rf /etc/anacron/*
echo "" > /etc/crontab
echo "" > /etc/anacrontab