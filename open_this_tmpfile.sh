#!/bin/bash
# stupid hack to open email attachments

#TODO: add some security stuff here.

export DISPLAY=:0

xdg-open $1
# some applications will notice the file unlink, and close the file.
# because of that, we want to have a small grace period for email attachments.
# but we want to delete things older than 12 hours. Should give enough time to
# work with a document.

find `dirname $1` -type f -cmin +720 -delete
