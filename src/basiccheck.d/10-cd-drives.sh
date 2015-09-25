RUNNAME="CD/DVD drives"

runfile_exec()
{
  local RET

  RUNOUT="$(/usr/lib/freegeek/show_cd_drives 2>&1)"
  RET=$?

  if (( RET == 0 )) && ! egrep -q '[^[:space:]]' <<< "$RUNOUT"
  then
    RUNOUT='No CD drives found.'
  fi

  return $RET
}
