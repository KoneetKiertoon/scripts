#!/bin/bash

shopt -s extglob

if ! XRANDR=$(which xrandr 2>/dev/null); then
  echo 'error: xrandr not found' >&2
  exit 1
fi

if [[ ! -e /proc/cpuinfo ]]; then
  echo 'error: /proc/cpuinfo not found' >&2
  exit 1
fi

#if [[ $USER != root ]]; then
#  gksu -m 'Password:' "$0"
#  exit 0
#fi

if ! LSHW=$(which lshw 2>/dev/null); then
  echo 'error: lshw not found' >&2
  exit 1
fi

get_cpuinfo()
{
  local CPUINFO x
  CPUINFO="$(cat /proc/cpuinfo)"
  x="$(grep '^model name' <<< "$CPUINFO"|head -1)"
  x="${x#*: }"
  CPUMODEL="$(echo $x)"
  x="$(grep '^cpu cores' <<< "$CPUINFO"|head -1)"
  CPUCORES="${x##* }"
}

get_resolutions()
{
  local l i
  ((i=0))
  while read l; do
    SCREENS[i]="${l%% *}"
    l="${l##*connected }"
    l="${l%%+*}"
    RESOLUTIONS[i]="${l/x/ x }"
    ((i++))
  done <<< "$($XRANDR 2>/dev/null|grep ' connected ')"
}

parse_lshw()
{
  local i c x n JSON LEN DEPTH NAME VALUE ID CLASS PRODUCT CPU DESCRIPTION CORES SIZE UNITS

  readarray -t i
  JSON="${i[@]}"
  unset i
  (( LEN=${#JSON} ))
  (( DEPTH=0 ))

  for ((i=0; i < LEN;)); do
    c="${JSON:i:1}"
    case "$c" in
    ' '|$'\t')
      (( i++ ))
      continue
      ;;

    '['|'{')
      (( DEPTH++ ))
      (( i++ ))
      continue
      ;;

    ']'|'}')
      (( DEPTH > 0 )) || return 1
      case "${CLASS[DEPTH]}" in
      'memory')
        if [[ "${ID[DEPTH]:0:5}" == 'bank:' && -n "${SIZE[DEPTH]}" ]]; then
          echo "RAM:   ${ID[DEPTH]}: ${DESCRIPTION[DEPTH]} ${SIZE[DEPTH]} ${UNITS[DEPTH]}"
        fi
        ;;
      'processor')
        CPU="CPU:   ${PRODUCT[DEPTH]//+([ $'\t'])/ }"$'\n'"Cores: $CORES"
        echo "$CPU"
        ;;
      esac
      CLASS[DEPTH]=
      DESCRIPTION[DEPTH]=
      ID[DEPTH]=
      PRODUCT[DEPTH]=
      SIZE[DEPTH]=
      UNITS[DEPTH]=
      (( DEPTH-- ))
      (( i++ ))
      continue
      ;;

    '"')
      # get name
      (( i++ ))
      (( x=i ))
      for ((;; i++ )); do
        (( i < LEN )) || return 2
        [[ "${JSON:i:1}" == '"' ]] && break
      done
      (( n=i-x ))
      (( i++ ))
	  NAME="${JSON:x:n}"

      # skip whitespace and colon
      for ((;; i++)); do
        (( i < LEN )) || return 3
        c="${JSON:i:1}"
        [[ "$c" == ' ' || "$c" == $'\t' ]] || break
      done
      [[ "$c" == ':' ]] || return 4
      for ((i++;; i++)); do
        (( i < LEN )) || return 5
        c="${JSON:i:1}"
        [[ "$c" == ' ' || "$c" == $'\t' ]] || break
      done

      # get value
      (( x=0 ))
      (( n=0 ))
      case "$c" in
      [0-9.]) # number
        (( x=i ))
        for ((i++;; i++)); do
          (( i < LEN )) || return 6
          case "${JSON:i:1}" in
          [0-9.]) continue ;;
          esac
          break
        done
        (( n=i-x ))
        VALUE="${JSON:x:n}"
        ;;

      '"') # string
        (( i++ ))
        (( x=i ))
        for ((;; i++)); do
          (( i < LEN )) || return 7
          [[ "${JSON:i:1}" == '"' ]] && break
        done
        (( n=i-x ))
        (( i++ ))
        VALUE="${JSON:x:n}"
        ;;

      '['|'{') # array or object
        (( DEPTH++ ))
        (( i++ ))
        continue
        ;;

      'f') # false
        (( i++ ))
        if [[ "${JSON:i:4}" == 'alse' ]]; then
          VALUE='false'
          (( i += 4 ))
        else
          return 8
        fi
        ;;

      'n') # null
        (( i++ ))
        if [[ "${JSON:i:3}" == 'ull' ]]; then
          VALUE='null'
          (( i += 3 ))
        else
          return 8
        fi
        ;;

      't') # true
        (( i++ ))
        if [[ "${JSON:i:3}" == 'rue' ]]; then
          VALUE='true'
          (( i += 3 ))
        else
          return 8
        fi
        ;;

      *) return 8 ;;
      esac

      case "$NAME" in
      'class')
        CLASS[DEPTH]="$VALUE"
        ;;
      'cores')
        CORES="$VALUE"
        ;;
      'description')
        DESCRIPTION[DEPTH]="$VALUE"
        ;;
      'id')
        ID[DEPTH]="$VALUE"
        ;;
      'product')
        PRODUCT[DEPTH]="$VALUE"
        ;;
      'size')
        SIZE[DEPTH]="$VALUE"
        ;;
      'units')
        UNITS[DEPTH]="$VALUE"
        ;;
      esac
      ;;

    ,) (( i++ )) ;;

    *) return 8 ;;
    esac
  done
}

generate_html()
{
  local i WIDTH_MM NAME_WIDTH_MM FONT
  ((WIDTH_MM=105))
  ((NAME_WIDTH_MM=20))
  FONT='"OpenDyslexic"'

  echo '<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Hardware info</title>
    <style>
      @font-face {
        font-family: OpenDyslexic;
        src: url("file:/usr/share/fonts/opentype/opendyslexic/OpenDyslexic-Regular.otf") format("opentype");
      }
      @font-face {
        font-family: OpenDyslexic;
        src: url("file:/usr/share/fonts/opentype/opendyslexic/OpenDyslexic-Bold.otf") format("opentype");
        font-weight: bold;
      }
      .component {
        display: block;
        overflow: hidden;
        border: 0.2mm solid grey;
        padding: 0.2mm;
        margin: 0mm;
        width: '"$WIDTH_MM"'mm;
        background-color: #000000;
      }
      .row {
        padding: 0.2mm;
        margin: 0.2mm;
        background-color: #ffffff;
      }
      .name {
        border: 0mm solid;
        font-family: '"$FONT"';
        font-weight: bold;
        text-align: center;
        float: left;
        width: '"$NAME_WIDTH_MM"'mm;
        background-color: #d8d8d8;
        margin: 0.2mm;
        padding: 0.2mm;
      }
      .value {
        border: 0mm solid;
        font-family: '"$FONT"';
        text-align: center;
        background-color: #ffffff;
        padding: 0.2mm;
        margin: 0.2mm;
        margin-left: '"$NAME_WIDTH_MM"'mm;
      }
    </style>
  </head>
  <body>'

  echo '    <section class="component">
      <div class="row">
        <aside class="name">CPU</aside>
        <div class="value">'"$CPUCORES-ydinsuoritin<br>$CPUMODEL"'</div>
      </div>
    </section>
    <section class="component">'
  for ((i = 0; i < ${#SCREENS[@]}; i++)); do
    echo '      <div class="row">
        <aside class="name">'"${SCREENS[i]}"'</aside>
        <div class="value">'"${RESOLUTIONS[i]}"'</div>
      </div>'
  done
  echo '    </section>'

  echo '  </body>
</html>'
}

get_cpuinfo
get_resolutions
generate_html

#$LSHW -json 2>/dev/null|parse_lshw
