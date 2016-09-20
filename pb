#!/bin/bash

rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}" 
}

MYNAME=$(getent passwd $USER | cut -d: -f5 | cut -d, -f1)
POSTER=`rawurlencode "$MYNAME"`
SYNTAX=text
# urlencode the content so special characters get through
# from: http://stackoverflow.com/a/2236014
# but need to read from stdin in python so argument list not too long

myurl=$(w3m https://pastebin.canonical.com -dump_extra -post \
  <( python -c "import sys,urllib; print 'poster={}&syntax={}&content={}'.format('$POSTER','$SYNTAX', urllib.quote(sys.stdin.read()))" )  \
  | sed -nr 's|W3m-current-url:(.*)|\1|p' \
  | tee /dev/stderr )
echo -n "${myurl%\\n}" | xsel -b

echo "URL is in clipboard."
# If the above fails to print out a URL,
# then you need to login manually to pastebin with w3m:
#   w3m https://pastebin.canonical.com
# TODO: catch that failure and print a message to stderr
