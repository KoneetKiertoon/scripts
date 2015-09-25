RUNNAME="Video card"

runfile_exec()
{
  local LSPCI="$(lspci)" RET

  if egrep 'VGA.*82845' <<< "$LSPCI"
  then
    RUNOUT='Video card type "Intel 82845" is bad'
    RET=1
  elif egrep 'VGA.*SiS.*771/671' <<< "$LSPCI"
  then
    RUNOUT='Video card type "SiS 771/671" is bad'
    RET=1
  else
    RUNOUT='Video card type seems to be OK.'
    RET=0
  fi

  return $RET
}
