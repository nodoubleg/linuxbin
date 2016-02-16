#!/bin/bash
pkill autokey
pkill autokey-gtk
sleep 1
nohup autokey-gtk 2>&1 > /dev/null &
