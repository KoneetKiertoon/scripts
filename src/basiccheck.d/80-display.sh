RUNNAME="displays"

runfile_exec()
{
  local l i x y SCREENS RESOLUTIONS

  ((i=0))
  while read l
  do
    SCREENS[i]="${l%% *}"
    if [[ "$l" == *disconnected* ]]
    then
      RESOLUTIONS[i]=''
    else
      l="${l##*connected }"
      l="${l%%+*}"
      x="${l%%x*}"
      y="${l##*x}"
      if (( y > x ))
      then
        ((l=x)); ((x=y)); ((y=l))
      fi
      RESOLUTIONS[i]="${x}x$y"
    fi
    ((i++))
  done <<< "$(/usr/bin/xrandr 2>/dev/null|grep 'connected '|grep -v '^VIRTUAL')"

  for ((i = 0; i < ${#SCREENS[@]}; i++)); do
    ((i == 0)) || echo -n ', '
    echo -n "${SCREENS[i]}"
    [[ ! ${RESOLUTIONS[i]} ]] || echo -n " (${RESOLUTIONS[i]})"
  done

  return 0
}
