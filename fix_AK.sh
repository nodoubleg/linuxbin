#!/bin/bash
pkill autokey
pkill autokey-gtk
logger "$0: sent autokey SIGTERM"
sleep 1
nohup autokey-qt 2>&1 > /dev/null &
logger "$0: autokey relaunch attempted"
