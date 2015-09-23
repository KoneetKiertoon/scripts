RUNNAME="Video card"

runfile_exec()
{
  local LSPCI="$(lspci)" MSG RET

  if egrep 'VGA.*82845' <<< "$LSPCI"
  then
    MSG='Video card type "Intel 82845" is bad'
    RET=1
  elif egrep 'VGA.*SiS.*771/671' <<< "$LSPCI"
  then
    MSG='Video card type "SiS 771/671" is bad'
    RET=1
  else
    MSG='Video card type seems to be OK.'
    RET=0
  fi

  echo "$MSG"
  return $RET
}
