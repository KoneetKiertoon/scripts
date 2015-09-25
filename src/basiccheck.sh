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
      SUMMARY KKNAME KKID BACKTITLE

BACKTITLE='[Press ESC to exit]'
DOT_D_PATH=/usr/lib/basiccheck.d
LOGFILE=/dev/shm/basiccheck.log
RUNFILES=("${DOT_D_PATH}"/*.sh)

for ((len=${#RUNFILES[@]}, i=0; i < len; i++))
do
  F="${RUNFILES[i]}"
  [[ -f "$F" ]] || continue

  unset RUNNAME RUNDESC runfile_exec RUNASROOT RUNREQUIRED RUNNORESULTS

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

  if (( RUNREQUIRED == 0 ))
  then
    /usr/bin/dialog --title 'Next command - koneetkiertoon.fi basic check' \
                    --backtitle "$BACKTITLE" \
                    --yesno "Run test \"${RUNNAMES[i]}\"?" 0 0
    RETVAL=$?
  else
    RETVAL=0
  fi

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
      echo -n "$DATE Failed to acquire root, " >> "$LOGFILE"

      if (( RUNREQUIRED == 0 ))
      then
        echo "skipping $F" >> "$LOGFILE"
        continue
      else
        echo "exiting because $F is non-optional" >> "$LOGFILE"
        exit 255
      fi
    fi

    SUDO_KEPT_ALIVE=1
  fi

  unset RUNOUT

  runfile_exec

  RUNVALS[i]=$?
  RUNMSGS[i]="$RUNOUT"

  # write script results to log file
  DATE=$(/bin/date --rfc-3339=seconds)
  echo "$DATE RUNMSGS[$i]=\"${RUNMSGS[i]}\""$'\n'"$DATE RUNVALS[$i]=${RUNVALS[i]}" >> "$LOGFILE"

  # append results to summary
  (( i == 0 )) || SUMMARY="$SUMMARY"$'\n\n'
  SUMMARY="$SUMMARY${RUNNAMES[i]}"$'\n'"$(sed 's|.|=|g' <<< "${RUNNAMES[i]}")"$'\n'"${RUNMSGS[i]}"

  if (( RUNVALS[i] != 0 && RUNREQUIRED != 0 ))
  then
    SUMMARY="$SUMMARY"$'\n'"Exiting because mandatory script $F failed"
    break
  fi

  if (( RUNNORESULTS == 0 ))
  then
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
                    --backtitle "$BACKTITLE" \
                    --msgbox "$MSG" 0 0

    RETVAL=$?
    DATE=$(/bin/date --rfc-3339=seconds)

    case $RETVAL in
    255) echo "$DATE ESC pressed, exiting" >> "$LOGFILE" ; exit 255 ;;
    esac
  fi
done

clear

echo "$SUMMARY"
