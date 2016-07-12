#!/bin/bash
# stupid hack to open email attachments

#TODO: add some security stuff here.

export DISPLAY=:0

xdg-open $1
# we can't get the pid from xdg-open, so we just wait and unlink, hoping the viewer holds the file open.
# told you it was stupid.
sleep 1
rm $1
