#!/bin/bash
set -x
sudo cp *_hourly /etc/cron.hourly
sudo chmod u+x /etc/cron.hourly/*_hourly
sudo cp *_daily /etc/cron.daily
sudo chmod u+x /etc/cron.daily/*_daily
sudo cp *_weekly /etc/cron.weekly
sudo chmod u+x /etc/cron.weekly/*_weekly
sudo cp *_monthly /etc/cron.monthly
sudo chmod u+x /etc/cron.monthly/*_monthly
