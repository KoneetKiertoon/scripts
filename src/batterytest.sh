#!/bin/bash
#
# Drain battery by downloading Youtube videos and playing them
# fullscreen. The purpose of this is to emulate casual computer
# use to measure battery life.
#
# Author: Juuso Alasuutari
# License: GPLv3
#
# Depends on: curl, ibam, youtube-dl*, mplayer2, xdotool
#
# *) NOTICE: If you run this on Ubuntu 12.04 you can't use the stock
#    youtube-dl package. You need a more recent version. Install one
#    from Webupd8's repository:
#
#    # apt-add-repository ppa:nilarimogard/webupd8
#    # apt-get update
#    # apt-get install youtube-dl
#

TIME="$(date +%s.%N)"

URL='https://www.youtube.com/'
DIR="$HOME/batterytest"
LOGDIR="$DIR/$TIME"
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
      DST="$LOGDIR/batt.log"
      RUNFILE="$RUN/$BASHPID"
      touch "$RUNFILE"
      T="$(date +%s.%N)"
      PREV="$(ibam -r --noprofile --percentbattery|head -1|cut -d' ' -f11)"
      T="$(bc -l <<< "($T-$TIME)/60"|sed -r 's|([1-9]\|\.0)0+$|\1|')"
      echo "$T $PREV" >> "$DST"
      while [[ -f "$RUNFILE" ]]; do
        sleep 5
        T="$(date +%s.%N)"
        IBAM="$(ibam -r --noprofile --percentbattery|head -1|cut -d' ' -f11)"
        if [[ "$IBAM" != "$PREV" ]]; then
          T="$(bc -l <<< "($T-$TIME)/60"|sed -r 's|([1-9]\|\.0)0+$|\1|')"
          echo "$T $IBAM" >> "$DST"
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
        T="$(date +%s.%N)"
        read a b c d e z < /proc/stat
        ((t=b+c+d+e))
        ((dt=t-_t))
        T="$(bc -l <<< "($T-$TIME)/60"|sed -r 's|([1-9]\|\.0)0+$|\1|')"
        V="$(bc -l <<< "$((100*(dt-(e-_e)))).0/${dt}.0"|sed -r 's|([1-9]\|\.0)0+$|\1|')"
        echo "$T $V" >> "$LOGDIR/cpu.log"
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
      DST="$LOGDIR/temp$N.log"
      RUNFILE="$RUN/$BASHPID"
      touch "$RUNFILE"
      T="$(date +%s.%N)"
      PREV=$(cat "$SRC")
      LEN="$((${#PREV}-3))"
      PREV="${PREV:0:LEN}.${PREV:LEN}"
      T="$(bc -l <<< "($T-$TIME)/60"|sed -r 's|([1-9]\|\.0)0+$|\1|')"
      echo "$T $PREV" >> "$DST"
      while [[ -f "$RUNFILE" ]]; do
        sleep 5
        T="$(date +%s.%N)"
        TEMP=$(cat "$SRC")
        LEN="$((${#TEMP}-3))"
        TEMP="${TEMP:0:LEN}.${TEMP:LEN}"
        if [[ "$TEMP" != "$PREV" ]]; then
          T="$(bc -l <<< "($T-$TIME)/60"|sed -r 's|([1-9]\|\.0)0+$|\1|')"
          echo "$T $TEMP" >> "$DST"
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
      DST="$LOGDIR/${X}x_$I.log"
      RUNFILE="$RUN/$BASHPID"
      touch "$RUNFILE"
      while [[ -f "$RUNFILE" ]]; do
        T="$(date +%s.%N)"
        V="$(cat "$SRC")"
        T="$(bc -l <<< "($T-$TIME)/60"|sed -r 's|([1-9]\|\.0)0+$|\1|')"
        echo "$T $V" >> "$DST"
        sleep 5
      done
    ) &>/dev/null &
  done
}

#
# Move the mouse cursor around to prevent inactivity triggers.
#
sleep_deprivation ()
{
  (
    RUNFILE="$RUN/$BASHPID"
    touch "$RUNFILE"
    for ((y=0;;)); do
      [[ -f "$RUNFILE" ]] || break
      for ((x=0; y < 180; y++)); do
        for ((k=0; k < 2; k++, x++)); do
          xdotool mousemove --polar $x $y
          sleep 0.005
        done
      done
      [[ -f "$RUNFILE" ]] || break
      for ((x=0; y > 0; y--)); do
        for ((k=0; k < 2; k++, x++)); do
          xdotool mousemove --polar $x $y
          sleep 0.005
        done
      done
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

mkdir -p "$LOGDIR" || exit 1
mkdir -p "$TMP" || exit 1

if [[ -d "$RUN" ]]; then
  rm -f "$RUN"/* &>/dev/null
else
  mkdir -p "$RUN" || exit 1
fi

if ! get_html_from_url; then
  exit 1
fi

cpu_logger
batt_logger
temp_logger
xmit_logger
sleep_deprivation

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
