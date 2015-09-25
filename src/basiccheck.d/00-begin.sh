RUNNAME="Basic information"
RUNREQUIRED=1
RUNNORESULTS=1

runfile_exec()
{
  local M n i N I

  ((n=16))
  ((i=16))
  N=""
  I=""

  while true
  do
    readarray -t M \
      < <(/usr/bin/dialog --backtitle '[Press Ctrl-C to exit]' --no-cancel \
                          --form "Basic information - koneetkiertoon.fi basic check" \
                          8 0 3 \
                          "Your name " 1 0 "$N" 1 12 $((n)) 64 \
                          "Machine ID" 3 0 "$I" 3 12 $((i)) 64 \
                          3>&1 1>&2 2>&3 | tee /dev/stderr)

    # TODO: how to carry over return value?
    #(( $? != 255 )) || exit 255

    if (( n > 0 ))
    then
      N="${M[0]}"
      if egrep -q '[^[:blank:]]+' <<< "$N"
      then
        (( i > 0 )) || break
        I="${M[1]}"
        if egrep -q '^2[0-9]{3}(0[1-9]|1[012])(0[1-9]|[12][0-9]|3[01])-[0-9]+$' <<< "$I"
        then
          break
        fi
        ((n=-16))

      elif (( i > 0 ))
      then
        I="${M[1]}"
        if egrep -q '^2[0-9]{3}(0[1-9]|1[012])(0[1-9]|[12][0-9]|3[01])-[0-9]+$' <<< "$I"
        then
          ((i=-16))
        fi
      fi

    elif (( i > 0 ))
    then
      I="${M[0]}"
      if egrep -q '^2[0-9]{3}(0[1-9]|1[012])(0[1-9]|[12][0-9]|3[01])-[0-9]+$' <<< "$I"
      then
        break
      fi
    fi
  done

  KKNAME="$N"
  KKID="$I"
  BACKTITLE="$BACKTITLE - $KKNAME working on machine $KKID"

  RUNOUT="Name: $KKNAME"$'\n'"Machine ID: $KKID"
}
