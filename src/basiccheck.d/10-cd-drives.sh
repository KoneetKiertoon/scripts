RUNNAME="freegeek_show_cd_drives"

runfile_exec()
{
  local MSG RET
  MSG="$(/usr/lib/freegeek/show_cd_drives 2>&1)"
  RET=$?
  if (( RET == 0 )) && ! egrep -q '[^[:space:]]' <<< "$MSG"
  then
    MSG='No CD drives found.'
  fi
  echo "$MSG"
  return $RET
}
