RUNNAME="Hardware info"
RUNASROOT=1

runfile_exec()
{
  local RET DEST

  DEST='/tmp/printme.xml'

  sudo lshw -xml 2>/dev/null > "$DEST"
  RET=$?

  if (( RET == 0 ))
  then
    echo "Hardware info written to $DEST"
  fi

  return $RET
}
