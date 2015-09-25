RUNNAME="Network"

runfile_exec()
{
  local ADDR RET

  if [[ $1 ]]
  then
    ADDR="$1"
  else
    ADDR='8.8.8.8'
  fi

  RUNOUT="$(ping -c 1 "$ADDR" 2>&1)"
  RET=$?

  return $RET
}
