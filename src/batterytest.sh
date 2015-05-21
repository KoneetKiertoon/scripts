#!/bin/bash
#
# Drain battery by downloading Youtube videos and playing them
# fullscreen. The purpose of this is to emulate casual computer
# use to measure battery life.
#
# Author: Juuso Alasuutari
# License: GPLv3
#
# Depends on: curl, ibam, youtube-dl*, mplayer2
#
# *) NOTICE: If you run this on Ubuntu 12.04 you can't use the stock
#    youtube-dl package. You need a more recent version. Install one
#    from Webupd8's repository:
#
#    # apt-add-repository ppa:nilarimogard/webupd8
#    # apt-get update
#    # apt-get install youtube-dl
#
# TODO: X=$(cat /proc/loadavg |cut -d' ' -f1); bc -l <<< "(100*$X)/2"|sed -r 's|([1-9])0+$|\1|'
#

URL='https://www.youtube.com/'
DIR="$HOME/batterytest"
TMP="$DIR/tmp"
RUN="$DIR/run"
HTML="$TMP/page.html"

#
# Log timestamp and battery level every five seconds.
#
batt_logger ()
{
  if [[ $(which ibam 2>/dev/null) ]]; then
    (
      DST="$DIR/batt.log"
      RUNFILE="$RUN/$BASHPID"
      touch "$RUNFILE"
      PREV="$(ibam -r --noprofile --percentbattery|head -1|cut -d' ' -f11)"
      echo "$(date '+%s.%N') $PREV" >> "$DST"
      while [[ -f "$RUNFILE" ]]; do
        sleep 5
        IBAM="$(ibam -r --noprofile --percentbattery|head -1|cut -d' ' -f11)"
        if [[ "$IBAM" != "$PREV" ]]; then
          echo "$(date '+%s.%N') $IBAM" >> "$DST"
          PREV="$IBAM"
        fi
      done
    ) &>/dev/null &
  else
    echo "Can't find ibam, battery logging not possible" >&2
  fi
}

#
# Log timestamp and CPU utilization.
#
cpu_logger ()
{
  if [[ -f /proc/stat ]]; then
    (
      RUNFILE="$RUN/$BASHPID"
      touch "$RUNFILE"
      read a b c d _e z < /proc/stat
      ((_t=b+c+d+_e))
      while [[ -f "$RUNFILE" ]]; do
        read a b c d e z < /proc/stat
        ((t=b+c+d+e))
        ((dt=t-_t))
        echo "$(date '+%s.%N') $(bc -l <<< $((100*(dt-(e-_e)))).0/${dt}.0)" >> "$DIR/cpu.log"
        ((_t=t))
        ((_e=e))
        sleep 1
      done
    ) &>/dev/null &
  else
    echo "Can't find /proc/stat, CPU logging not possible" >&2
  fi
}

#
# Log timestamp and available temperature readings every five seconds.
#
temp_logger ()
{
  ls -1 /sys/class/thermal/thermal_zone*/temp 2>/dev/null \
  | while read x; do
    N=$(egrep -o '[0-9]+' <<< "$x")
    (
      SRC="/sys/class/thermal/thermal_zone$N/temp"
      DST="$DIR/temp$N.log"
      RUNFILE="$RUN/$BASHPID"
      touch "$RUNFILE"
      PREV=$(cat "$SRC")
      LEN="$((${#PREV}-3))"
      PREV="${PREV:0:LEN}.${PREV:LEN}"
      echo $(date '+%s.%N') $PREV >> "$DST"
      while [[ -f "$RUNFILE" ]]; do
        sleep 5
        TEMP=$(cat "$SRC")
        LEN="$((${#TEMP}-3))"
        TEMP="${TEMP:0:LEN}.${TEMP:LEN}"
        if [[ "$TEMP" != "$PREV" ]]; then
          echo $(date '+%s.%N') ${TEMP} >> "$DST"
          PREV="$TEMP"
        fi
      done
    ) &>/dev/null &
  done
}

#
# Log network interface traffic (number of sent and received bytes).
#
xmit_logger ()
{
  ls -1 /sys/class/net/*[0-9]/statistics/[rt]x_bytes 2>/dev/null \
  | while read x; do
    X="${x%x_bytes}"
    X="${X##*/}"
    I="${x#/sys/class/net/}"
    I="${I%%/*}"
    (
      SRC="$x"
      DST="$DIR/${X}x_$I.log"
      RUNFILE="$RUN/$BASHPID"
      touch "$RUNFILE"
      while [[ -f "$RUNFILE" ]]; do
        echo $(date '+%s.%N') $(cat "$SRC") >> "$DST"
        sleep 5
      done
    ) &>/dev/null &
  done
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
mkdir -p "$RUN" || exit 1

if ! get_html_from_url; then
  exit 1
fi

cpu_logger
batt_logger
temp_logger
xmit_logger

while true; do
  get_vids_from_html
  get_random_url_from_vids

  rm ${TMP}/*

  if youtube-dl --no-cache-dir --no-playlist --ignore-config \
                -o "$TMP/vid.%(ext)s" "$URL"; then
    VID="$TMP/$(ls -1tr "$TMP/"|grep -v "html$"|tail -1)"
    xset s off
    xset -dpms
    mplayer --fs --ao=null "$VID"
    xset s
    xset +dpms
  fi

  get_html_from_url
done
