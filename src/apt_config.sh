#!/bin/bash

if [[ $USER != root ]]; then
  gksu -m 'Anna salasanasi:' "$0"
  exit 0
fi

LOGFILE='/var/log/koneetkiertoon.log'

file_contains_other_lines_than()
{
  egrep -qv "$2" 2>/dev/null < "$1"
}

fix_apt_cache_size()
{
  local MIN_CACHE_SIZE CONFFILE CACHE_SIZE TMP x

  MIN_CACHE_SIZE="$1"
  CONFFILE="$2"

  if (( MIN_CACHE_SIZE < 1 )); then
    echo 'error: invalid MIN_CACHE_SIZE' >> "$LOGFILE"
    return 1
  fi
  if [[ -z $CONFFILE ]]; then
    echo 'error: no filename' >> "$LOGFILE"
    return 1
  fi

  CACHE_SIZE=$(apt-config dump \
               | egrep '^[ \t]*APT::Cache-Start[ \t]+.*[0-9]+.*;' \
               | sed -r 's|^[^1-9]*0*([1-9][0-9]*\|0)[^0-9]*$|\1|')

  if [[ $CACHE_SIZE ]]; then
    if (( CACHE_SIZE >= MIN_CACHE_SIZE )); then
      echo "APT::Cache-Start is $CACHE_SIZE bytes: large enough" >> "$LOGFILE"
      return 0
    else
      echo "APT::Cache-Start is $CACHE_SIZE: too small" >> "$LOGFILE"
    fi
  else
    echo 'APT::Cache-Start is undefined: assuming zero' >> "$LOGFILE"
    CACHE_SIZE='0'
  fi

  TMP=$(egrep -l '^[ \t]*APT::Cache-Start[ \t]+.*[0-9]+.*;' \
        /etc/apt/apt.conf /etc/apt/apt.conf.d/* 2>/dev/null)

  if [[ "$TMP" ]]; then
    while read x; do
      echo "Found existing config line(s) in $x:" >> "$LOGFILE"
      egrep 'APT::Cache-Start' "$x"|sed -r 's|^(.*)$|  \1|' >> "$LOGFILE"
      sed -ri 's|^([ \t]*APT::Cache-Start[ \t]+.*)$|#\1|' "$x"
      echo "Changed to:" >> "$LOGFILE"
      egrep 'APT::Cache-Start' "$x"|sed -r 's|^(.*)$|  \1|' >> "$LOGFILE"
    done <<< "$TMP"
  fi

  if [[ -e "$CONFFILE" ]] &&
     file_contains_other_lines_than \
       "$CONFFILE" '^[ \t]*#?APT::Cache-Start[ \t].*$'
  then
    echo "Appending new config line to $CONFFILE" >> "$LOGFILE"
    echo "APT::Cache-Start \"$MIN_CACHE_SIZE\";" >> "$CONFFILE"
  else
    echo "Overwriting $CONFFILE with new config line" >> "$LOGFILE"
    echo "APT::Cache-Start \"$MIN_CACHE_SIZE\";" > "$CONFFILE"
  fi
}

fix_apt_cache_size 134217728 /etc/apt/apt.conf.d/01cache
