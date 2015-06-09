#!/bin/bash

if [[ $USER != root ]]; then
  gksu -m 'Password:' "$0"
  exit 0
fi

if ! LSHW=$(which lshw 2>/dev/null); then
  echo 'error: lshw not found' >&2
  exit 1
fi

parse_lshw()
{
  local i c x n JSON LEN DEPTH NAME VALUE

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
      echo -n "$c"
      (( DEPTH++ ))
      (( i++ ))
      continue
      ;;

    ']'|'}')
      (( DEPTH > 0 )) || return 1
      echo -n "$c"
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
      NAME[DEPTH]="${JSON:x:n}"

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
        VALUE[DEPTH]="${JSON:x:n}"
        echo -n "\"${NAME[DEPTH]}\":${VALUE[DEPTH]}"
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
        VALUE[DEPTH]="\"${JSON:x:n}\""
        echo -n "\"${NAME[DEPTH]}\":${VALUE[DEPTH]}"
        ;;

      '['|'{') # array or object
        VALUE[DEPTH]="$c"
        echo -n "\"${NAME[DEPTH]}\":${VALUE[DEPTH]}"
        (( DEPTH++ ))
        (( i++ ))
        continue
        ;;

      'f') # false
        (( i++ ))
        if [[ "${JSON:i:4}" == 'alse' ]]; then
          VALUE[DEPTH]='false'
          echo -n "\"${NAME[DEPTH]}\":${VALUE[DEPTH]}"
          (( i += 4 ))
        else
          return 8
        fi
        ;;

      'n') # null
        (( i++ ))
        if [[ "${JSON:i:3}" == 'ull' ]]; then
          VALUE[DEPTH]='null'
          echo -n "\"${NAME[DEPTH]}\":${VALUE[DEPTH]}"
          (( i += 3 ))
        else
          return 8
        fi
        ;;

      't') # true
        (( i++ ))
        if [[ "${JSON:i:3}" == 'rue' ]]; then
          VALUE[DEPTH]='true'
          echo -n "\"${NAME[DEPTH]}\":${VALUE[DEPTH]}"
          (( i += 3 ))
        else
          return 8
        fi
        ;;

      *) return 8 ;;
      esac
      ;;

    ,) echo -n "$c"
       (( i++ ))
       ;;

    *) return 8 ;;
    esac
  done
}

$LSHW -json|parse_lshw
