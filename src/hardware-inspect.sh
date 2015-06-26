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

if ! DMIDECODE=$(which dmidecode 2>/dev/null); then
  echo 'error: dmidecode not found' >&2
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

if ! JSHON=$(which jshon 2>/dev/null); then
  echo 'error: jshon not found' >&2
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

get_meminfo()
{
  local l x i m n t

  ((x=0))
  ((i=0))
  while read l; do
    if (( x == 2 )); then
      case "$l" in
      'Maximum Capacity:'*)
        MEM_MAX[i]="${l#*: }"
        ;;
      'Number Of Devices:'*)
        MEM_NUM[i]="${l#*: }"
        ;;
      'Physical Memory Array')
        ((i++))
        ((x=1))
        m=
        n=
        ;;
      esac
    elif (( x == 1 )); then
      case "$l" in
      'Maximum Capacity:'*)
        m="${l#*: }"
        ;;
      'Number Of Devices:'*)
        n="${l#*: }"
        ;;
      'Use: System Memory')
        ((x=2))
        if [[ $m ]]; then
          MEM_MAX[i]="$m"
          m=
        fi
        if [[ $n ]]; then
          MEM_NUM[i]="$n"
          n=
        fi
        ;;
      esac
    elif [[ "$l" == 'Physical Memory Array' ]]; then
      ((x=1))
    fi
  done <<< "$($DMIDECODE -t 16 2>/dev/null|egrep -o '[^[:cntrl:]]+')"

  # temporary testing output
#  for ((i=0; i<${#MEM_MAX[@]}; i++)); do
#    echo "$i : slots: ${MEM_NUM[i]}, max: ${MEM_MAX[i]}"
#  done

  ((x=0))
  ((i=0))
  while read l; do
    if (( x == 2 )); then
      case "$l" in
      'Size:'*)
        m="${l#*Size: }"
        if [[ "$m" == No* ]]; then
          MEM_BANK_SIZE[i]='0'
        else
          MEM_BANK_SIZE[i]="$m"
        fi
        ;;
      'Speed:'*)
        n="${l#*Speed: }"
        if [[ "$n" == Un* ]]; then
          MEM_BANK_SPEED[i]=''
        else
          MEM_BANK_SPEED[i]="$n"
        fi
        ;;
      'Type:'*)
        t="${l#*Type: }"
        if [[ "$t" == Un* ]]; then
          MEM_BANK_TYPE[i]=''
        else
          MEM_BANK_TYPE[i]="$t"
        fi
        ;;
      'Memory Device')
        ((i++))
        ((x=1))
        m=
        n=
        t=
        ;;
      esac
    elif (( x == 1 )); then
      case "$l" in
      'Size:'*)
        m="${l#*Size: }"
        if [[ "$m" == No* ]]; then
          m='0'
        fi
        ;;
      'Speed:'*)
        n="${l#*Speed: }"
        if [[ "$n" == Un* ]]; then
          n=''
        fi
        ;;
      'Type:'*)
        t="${l#*Type: }"
        ;;
      'Form Factor: '*'DIMM')
        ((x=2))
        MEM_BANK_FORM[i]="${l#*Form Factor: }"
        if [[ $t ]]; then
          MEM_BANK_TYPE[i]="$t"
          t=
        else
          MEM_BANK_TYPE[i]=''
        fi
        if [[ $m ]]; then
          MEM_BANK_SIZE[i]="$m"
          m=
        fi
        if [[ $n ]]; then
          MEM_BANK_SPEED[i]="$n"
          n=
        else
          MEM_BANK_SPEED[i]=''
        fi
        ;;
      esac
    elif [[ "$l" == 'Memory Device' ]]; then
      ((x=1))
    fi
  done <<< "$($DMIDECODE -t 17 2>/dev/null|egrep -o '[^[:cntrl:]]+')"

  ((MEM_TOTAL=0))
  for ((i=0; i<${#MEM_BANK_FORM[@]}; i++)); do
    m="$(egrep -o '[0-9]+' <<< "${MEM_BANK_SIZE[i]}")"
    if [[ ${MEM_BANK_SIZE[i]} == *GB ]]; then
      (( m *= 1024 ))
    elif [[ ${MEM_BANK_SIZE[i]} != *MB ]]; then
      (( m = 0 ))
    fi
    (( MEM_TOTAL += m ))
  done
}

get_resolutions()
{
  local l i x y
  ((i=0))
  while read l; do
    SCREENS[i]="${l%% *}"
    if [[ "$l" == *disconnected* ]]; then
      RESOLUTIONS[i]=''
    else
      l="${l##*connected }"
      l="${l%%+*}"
      x="${l%%x*}"
      y="${l##*x}"
      if (( y > x )); then
        ((l=x)); ((x=y)); ((y=l))
      fi
      RESOLUTIONS[i]="${x}x$y"
    fi
    ((i++))
  done <<< "$($XRANDR 2>/dev/null|grep 'connected '|grep -v '^VIRTUAL')"
}

generate_html()
{
  local i WIDTH_MM NAME_WIDTH_MM FONT FONT_SIZE_MM FONT_SIZE_SMALLISH_MM FONT_SIZE_SMALL_MM
  ((WIDTH_MM=105))
  ((NAME_WIDTH_MM=20))
  FONT_SIZE_MM='5'
  FONT_SIZE_SMALLISH_MM='4'
  FONT_SIZE_SMALL_MM='3.5'
  FONT='"OpenDyslexic"'

  echo '<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>Hardware info</title>
    <style>
      @font-face {
        font-family: OpenDyslexic;
        src: url("file:/usr/share/fonts/opentype/opendyslexic/OpenDyslexic-Regular.otf") format("opentype"),
             url("file:./OpenDyslexic-Regular.otf") format("opentype");
        font-weight: normal;
        font-style: normal;
      }
      @font-face {
        font-family: OpenDyslexic;
        src: url("file:/usr/share/fonts/opentype/opendyslexic/OpenDyslexic-Bold.otf") format("opentype"),
             url("file:./OpenDyslexic-Bold.otf") format("opentype");
        font-weight: bold;
        font-style: normal;
      }
      @font-face {
        font-family: OpenDyslexic;
        src: url("file:/usr/share/fonts/opentype/opendyslexic/OpenDyslexic-Italic.otf") format("opentype"),
             url("file:./OpenDyslexic-Italic.otf") format("opentype");
        font-weight: normal;
        font-style: italic;
      }
      @font-face {
        font-family: OpenDyslexic;
        src: url("file:/usr/share/fonts/opentype/opendyslexic/OpenDyslexic-BoldItalic.otf") format("opentype"),
             url("file:./OpenDyslexic-BoldItalic.otf") format("opentype");
        font-weight: bold;
        font-style: italic;
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
        display: table;
        padding: 0.2mm;
        margin: 0.2mm;
        background-color: #ffffff;
      }
      .name {
        display: table-cell;
        border: 0mm solid;
        font-family: '"$FONT"';
        font-size: '"$FONT_SIZE_MM"'mm;
        font-weight: bold;
        text-align: center;
        width: '"$NAME_WIDTH_MM"'mm;
        background-color: #d8d8d8;
        margin: 0.2mm;
        padding: 0.2mm;
        /*-webkit-animation: horrible 1s infinite;
        animation: horrible 1s infinite;*/
      }
      .value {
        display: table-cell;
        border: 0mm solid;
        font-family: '"$FONT"';
        font-size: '"$FONT_SIZE_MM"'mm;
        text-align: center;
        background-color: #ffffff;
        padding: 0.2mm;
        margin: 0.2mm;
        margin-left: '"$NAME_WIDTH_MM"'mm;
        width: '"$((WIDTH_MM-NAME_WIDTH_MM))"'mm;
      }
      p.ital {
        font-family: '"$FONT"';
        font-style: italic;
        font-size: '"$FONT_SIZE_SMALL_MM"'mm;
        text-align: center;
        border: 0mm solid;
        padding: 0mm;
        margin: 0mm;
      }
      ol.ital {
        font-family: '"$FONT"';
        font-style: italic;
        font-size: '"$FONT_SIZE_SMALLISH_MM"'mm;
        text-align: left;
        border: 0mm solid;
        margin: 0mm;
      }
      /*@-webkit-keyframes horrible {
        50% {font-size: '"$FONT_SIZE_SMALL_MM"'mm;}
      }
      @keyframes horrible {
        50% {font-size: '"$FONT_SIZE_SMALL_MM"'mm;}
      }*/
    </style>
  </head>
  <body>
    <section class="component">
      <div class="row">
        <aside class="name">CPU</aside>
        <div class="value">'"$CPUCORES"'-ydinsuoritin<p class="ital">'"$CPUMODEL"'</p></div>
      </div>
    </section>
    <section class="component">
      <div class="row">
        <aside class="name">Muisti</aside>
        <div class="value">
          Kokonaism&auml;&auml;r&auml;: '"$MEM_TOTAL"' MiB
          <ol class="ital">'
  for ((i = 0; i < ${#MEM_BANK_FORM[@]}; i++)); do
    echo -n "            <li>${MEM_BANK_TYPE[i]} "
    if [[ "${MEM_BANK_SIZE[i]}" == '0' ]]; then
      echo -n '&lt;tyhj&auml;&gt;'
    else
      echo -n "${MEM_BANK_SPEED[i]} ${MEM_BANK_SIZE[i]}"
    fi
    echo '</li>'
  done
  echo '          </ol>
        </div>
      </div>
    </section>
    <section class="component">
      <div class="row">
        <aside class="name">Kuva</aside>
        <div class="value">'
  for ((i = 0; i < ${#SCREENS[@]}; i++)); do
    ((i == 0)) || echo -n ', '
    echo -n "${SCREENS[i]}"
    [[ ! ${RESOLUTIONS[i]} ]] || echo -n " (${RESOLUTIONS[i]})"
  done
  echo '</div>
      </div>
    </section>
  </body>
</html>'
}

json_array()
{
  local JSON DEPTH LEN NUM TYPE i

  JSON="$1"
  DEPTH="$2"
  LEN="$("$JSHON" -l <<< "$JSON")"

  for ((NUM=0; NUM<LEN; NUM++)); do
    TYPE="$("$JSHON" -e $((NUM)) -t <<< "$JSON")"
    case "$TYPE" in
    'array')
      for ((i=0; i<DEPTH; i++)); do
        echo -n ' '
      done
      echo "["
      json_array "$("$JSHON" -e $((NUM)) <<< "$JSON")" $((DEPTH+1))
      for ((i=0; i<DEPTH; i++)); do
        echo -n ' '
      done
      echo ']'
      ;;
    'object')
      for ((i=0; i<DEPTH; i++)); do
        echo -n ' '
      done
      echo "{"
      json_object "$("$JSHON" -e $((NUM)) <<< "$JSON")" $((DEPTH+1))
      for ((i=0; i<DEPTH; i++)); do
        echo -n ' '
      done
      echo '}'
      ;;
    esac
  done
}

json_object()
{
  local JSON DEPTH KEYS KEY TYPE i

  JSON="$1"
  DEPTH="$2"
  KEYS="$("$JSHON" -k <<< "$JSON")"

  for KEY in $KEYS; do
    TYPE="$("$JSHON" -e "$KEY" -t <<< "$JSON")"
    case "$TYPE" in
    'array')
      for ((i=0; i<DEPTH; i++)); do
        echo -n ' '
      done
      echo "$KEY : ["
      json_array "$("$JSHON" -e "$KEY" <<< "$JSON")" $((DEPTH+1))
      for ((i=0; i<DEPTH; i++)); do
        echo -n ' '
      done
      echo ']'
      ;;
    'object')
      for ((i=0; i<DEPTH; i++)); do
        echo -n ' '
      done
      echo "$KEY : {"
      json_object "$("$JSHON" -e "$KEY" <<< "$JSON")" $((DEPTH+1))
      for ((i=0; i<DEPTH; i++)); do
        echo -n ' '
      done
      echo '}'
      ;;
    'string')
      for ((i=0; i<DEPTH; i++)); do
        echo -n ' '
      done
      echo "$KEY : $("$JSHON" -e "$KEY" -u <<< "$JSON")"
      ;;
    esac
  done
}

parse_lshw()
{
  local JSON

  JSON="$("$LSHW" -json 2>/dev/null)"

  if [[ $("$JSHON" -t <<< "$JSON") != 'object' ||
        $("$JSHON" -e class -u <<< "$JSON") != 'system' ]]; then
    echo 'Got invalid JSON output from lshw' >&2
    return 1
  fi

  json_object "$JSON"
}

get_meminfo
#parse_lshw
get_cpuinfo
get_resolutions
generate_html
