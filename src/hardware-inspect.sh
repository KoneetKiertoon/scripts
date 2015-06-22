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

#if ! LSHW=$(which lshw 2>/dev/null); then
#  echo 'error: lshw not found' >&2
#  exit 1
#fi

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
  local i WIDTH_MM NAME_WIDTH_MM FONT FONT_SIZE_MM FONT_SIZE_SMALL_MM
  ((WIDTH_MM=105))
  ((NAME_WIDTH_MM=20))
  FONT_SIZE_MM='5'
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
        padding: 0.2mm;
        margin: 0.2mm;
        background-color: #ffffff;
      }
      .name {
        border: 0mm solid;
        font-family: '"$FONT"';
        font-size: '"$FONT_SIZE_MM"'mm;
        font-weight: bold;
        text-align: center;
        float: left;
        width: '"$NAME_WIDTH_MM"'mm;
        background-color: #d8d8d8;
        margin: 0.2mm;
        padding: 0.2mm;
        /*-webkit-animation: horrible 1s infinite;
        animation: horrible 1s infinite;*/
      }
      .value {
        border: 0mm solid;
        font-family: '"$FONT"';
        font-size: '"$FONT_SIZE_MM"'mm;
        text-align: center;
        background-color: #ffffff;
        padding: 0.2mm;
        margin: 0.2mm;
        margin-left: '"$NAME_WIDTH_MM"'mm;
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
      /*@-webkit-keyframes horrible {
        50% {font-size: '"$FONT_SIZE_SMALL_MM"'mm;}
      }
      @keyframes horrible {
        50% {font-size: '"$FONT_SIZE_SMALL_MM"'mm;}
      }*/
    </style>
  </head>
  <body>'

  echo '    <section class="component">
      <div class="row">
        <aside class="name">CPU</aside>
        <div class="value">'"$CPUCORES"'-ydinsuoritin<p class="ital">'"$CPUMODEL"'</p></div>
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

get_cpuinfo
get_resolutions
generate_html
