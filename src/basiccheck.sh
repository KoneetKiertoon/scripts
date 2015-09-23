#!/bin/bash

acquire_root()
{
  if ! sudo -v
  then
    return 1
  fi

  while true
  do
    sudo -n true
    sleep 15
    kill -0 "$$" || exit
  done 2>/dev/null &

  return 0
}

unset DOT_D_PATH LOGFILE RUNFILES RUNNAMES RUNVALS RUNMSGS SUDO_KEPT_ALIVE \
      SUMMARY

# TODO: this path is temporary, will eventually
# become something like /usr/lib/basiccheck.d
DOT_D_PATH=/git/koneetkiertoon-scripts/src/basiccheck.d
LOGFILE=/dev/shm/basiccheck.log

RUNFILES=("${DOT_D_PATH}"/*.sh)

for ((len=${#RUNFILES[@]}, i=0; i < len; i++))
do
  F="${RUNFILES[i]}"
  [[ -f "$F" ]] || continue

  unset RUNNAME RUNDESC runfile_exec RUNASROOT

  . "$F"

  RETVAL=$?
  DATE=$(/bin/date --rfc-3339=seconds)

  if (( RETVAL != 0 ))
  then
    echo "$DATE Failed to source ${F}" >> "$LOGFILE"
    continue
  elif [[ $(type -t runfile_exec) != function ]]
  then
    echo "$DATE No runfile_exec() definition found in ${F}" >> "$LOGFILE"
    continue
  fi

  if [[ $RUNNAME ]]
  then
    RUNNAMES[i]="$RUNNAME"
  else
    RUNNAMES[i]="${F##*/}"
  fi

  MSG="Run test \"${RUNNAMES[i]}\"?"

  /usr/bin/dialog --title 'Next command - koneetkiertoon.fi basic check' \
                  --backtitle '[Press ESC to exit]' \
                  --yesno "$MSG" 0 0

  RETVAL=$?
  DATE=$(/bin/date --rfc-3339=seconds)

  case $RETVAL in
  0) echo "$DATE Running $F" >> "$LOGFILE" ;;
  1) echo "$DATE Skipping $F" >> "$LOGFILE" ; continue ;;
  255) echo "$DATE ESC pressed, exiting" >> "$LOGFILE" ; exit 255 ;;
  esac

  if [[ -n $RUNASROOT && -z $SUDO_KEPT_ALIVE ]]
  then
    DATE=$(/bin/date --rfc-3339=seconds)
    echo "$DATE Trying to to acquire root" >> "$LOGFILE"
    if ! acquire_root
    then
      DATE=$(/bin/date --rfc-3339=seconds)
      echo "$DATE Failed to acquire root, skipping $F" >> "$LOGFILE"
      continue
    fi
    SUDO_KEPT_ALIVE=1
  fi

  RUNMSGS[i]="$(runfile_exec)"
  RUNVALS[i]=$?

  # write script results to log file
  DATE=$(/bin/date --rfc-3339=seconds)
  echo "$DATE RUNMSGS[$i]=\"${RUNMSGS[i]}\""$'\n'"$DATE RUNVALS[$i]=${RUNVALS[i]}" >> "$LOGFILE"

  # append results to summary
  (( i == 0 )) || SUMMARY="$SUMMARY"$'\n\n'
  SUMMARY="$SUMMARY${RUNNAMES[i]}"$'\n'"$(sed 's|.|=|g' <<< "${RUNNAMES[i]}")"$'\n'"${RUNMSGS[i]}"

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
  DATE=$(/bin/date --rfc-3339=seconds)

  case $RETVAL in
  255) echo "$DATE ESC pressed, exiting" >> "$LOGFILE" ; exit 255 ;;
  esac
done

clear

echo "$SUMMARY"
