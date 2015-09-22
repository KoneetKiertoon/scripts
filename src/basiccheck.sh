#!/bin/bash

unset DOT_D_PATH LOGFILE RUNFILES RUNVALS RUNMSGS

# TODO: this path is temporary, will eventually
# become something like /usr/lib/basiccheck.d
DOT_D_PATH=/git/koneetkiertoon-scripts/src/basiccheck.d
LOGFILE=/dev/shm/basiccheck.log

RUNFILES=("${DOT_D_PATH}"/*.sh)

for ((len=${#RUNFILES[@]}, i=0; i < len; i++))
do
  F="${RUNFILES[i]}"
  [[ -f "$F" ]] || continue

  unset RUNNAME RUNDESC runfile_exec

  . "$F" || continue

  if [[ $RUNNAME ]]
  then
    MSG="Run test \"$RUNNAME\"?"
  else
    MSG="Run test ${F##*/}?"
  fi

  /usr/bin/dialog --title 'Next command - koneetkiertoon.fi basic check' \
                  --backtitle '[Press ESC to exit]' \
                  --yesno "$MSG" 0 0

  RETVAL=$?
  DATE=$(/bin/date --rfc-3339=ns)

  case $RETVAL in
  0) echo "$DATE Running $F" >> "$LOGFILE" ;;
  1) echo "$DATE Skipping $F" >> "$LOGFILE" ; continue ;;
  255) echo "$DATE ESC pressed, exiting" >> "$LOGFILE" ; exit 255 ;;
  esac

  RUNMSGS[i]="$(runfile_exec)"
  RUNVALS[i]=$?

  # write script results to log file
  DATE=$(/bin/date --rfc-3339=ns)
  echo "$DATE RUNMSGS[$i]=\"${RUNMSGS[i]}\""$'\n'"$DATE RUNVALS[$i]=${RUNVALS[i]}" >> "$LOGFILE"

  # display script results
  case ${RUNVALS[i]} in
  0) MSG='Command completed successfully.' ;;
  *) MSG="Command failed with return value ${RUNVALS[i]}" ;;
  esac

  if [[ -n ${RUNMSGS[i]} ]]
  then
    MSG="$MSG"$'\n'"Command output was:"$'\n\n'"${RUNMSGS[i]}"
  fi

  /usr/bin/dialog --title 'Command results - koneetkiertoon.fi basic check' \
                  --backtitle '[Press ESC to exit]' \
                  --msgbox "$MSG" 0 0

  RETVAL=$?
  DATE=$(/bin/date --rfc-3339=ns)

  case $RETVAL in
  255) echo "$DATE ESC pressed, exiting" >> "$LOGFILE" ; exit 255 ;;
  esac
done
