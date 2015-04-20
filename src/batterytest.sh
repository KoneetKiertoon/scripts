#!/bin/bash
#
# Drain battery by opening Youtube pages in Firefox.
# The purpose of this is to emulate casual computer
# use and measure battery life.
#
# Author: Juuso Alasuutari
# License: GPLv3
#
# Depends on: curl, ibam, youtube-dl, mpv
#

URL='https://www.youtube.com/'
DIR='/dev/shm/batterytest'
TMP="$DIR/tmp"
HTML="$TMP/page.html"

#
# Log timestamp, battery level, and
# load average every five seconds.
#
background_logger ()
{
  (
    while true; do
      echo "$(date '+%s.%N') $(ibam -r --noprofile --percentbattery|head -1|cut -d' ' -f11) $(cat /proc/loadavg)" >> "$HOME/batterytest.log"
      sleep 6
    done
  ) &>/dev/null &
}

#
# Download the HTML page that $URL points to.
# The page is written to the file $HTML.
#
get_html_from_url ()
{
  curl -o "$HTML" "$URL" &>/dev/null
}

#
# Extract all Youtube video IDs from saved HTML file,
# sort the list, and write to array $VIDS.
#
get_vids_from_html ()
{
  VIDS=($(egrep -o 'href="[^"]*watch\?[^"]+"' "$HTML" \
          | sed -r 's|.*[?&]v=([^?&"]+).*|\1|' | sort -u))
}

#
# Choose a random video ID from the $VIDS array, construct
# a new Youtube URL from it, and write to variable $URL.
#
get_random_url_from_vids ()
{
  local n=${#VIDS[@]}
  local r=$(($RANDOM % $n))
  URL="https://www.youtube.com/watch?v=${VIDS[r]}"
}

mkdir -p "$TMP" || exit 1

if ! get_html_from_url; then
  exit 1
fi

background_logger

while true; do
  get_vids_from_html
  get_random_url_from_vids

  if youtube-dl --no-cache-dir --no-playlist --ignore-config \
                -o "$TMP/vid.%(ext)s" "$URL"; then
    VID="$TMP/$(ls -1tr "$TMP/"|grep -v "html$"|tail -1)"
    mpv --fs "$VID"
  fi

  rm ${TMP}/*

  get_html_from_url
done
