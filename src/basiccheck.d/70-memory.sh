RUNNAME="memory size"
RUNASROOT=1

runfile_exec()
{
  local l x i m n t BANK_FORM BANK_SIZE BANK_SPEED BANK_TYPE MEM_MAX MEM_NUM

  ((x=0))
  ((i=0))

  while read l
  do
    if (( x == 2 ))
    then
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
    elif (( x == 1 ))
    then
      case "$l" in
      'Maximum Capacity:'*)
        m="${l#*: }"
        ;;
      'Number Of Devices:'*)
        n="${l#*: }"
        ;;
      'Use: System Memory')
        ((x=2))
        if [[ $m ]]
        then
          MEM_MAX[i]="$m"
          m=
        fi
        if [[ $n ]]
        then
          MEM_NUM[i]="$n"
          n=
        fi
        ;;
      esac
    elif [[ "$l" == 'Physical Memory Array' ]]
    then
      ((x=1))
    fi
  done <<< "$(sudo /usr/sbin/dmidecode -t 16 2>/dev/null|egrep -o '[^[:cntrl:]]+')"

  ((x=0))
  ((i=0))
  while read l
  do
    if (( x == 2 ))
    then
      case "$l" in
      'Size:'*)
        m="${l#*Size: }"
        if [[ "$m" == No* ]]
        then
          BANK_SIZE[i]='0'
        else
          BANK_SIZE[i]="$m"
        fi
        ;;
      'Speed:'*)
        n="${l#*Speed: }"
        if [[ "$n" == Un* ]]
        then
          BANK_SPEED[i]=''
        else
          BANK_SPEED[i]="$n"
        fi
        ;;
      'Type:'*)
        t="${l#*Type: }"
        if [[ "$t" == Un* ]]
        then
          BANK_TYPE[i]=''
        else
          BANK_TYPE[i]="$t"
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
    elif (( x == 1 ))
    then
      case "$l" in
      'Size:'*)
        m="${l#*Size: }"
        if [[ "$m" == No* ]]
        then
          m='0'
        fi
        ;;
      'Speed:'*)
        n="${l#*Speed: }"
        if [[ "$n" == Un* ]]
        then
          n=''
        fi
        ;;
      'Type:'*)
        t="${l#*Type: }"
        ;;
      'Form Factor: '*'DIMM')
        ((x=2))
        BANK_FORM[i]="${l#*Form Factor: }"
        if [[ $t ]]
        then
          BANK_TYPE[i]="$t"
          t=
        else
          BANK_TYPE[i]=''
        fi
        if [[ $m ]]
        then
          BANK_SIZE[i]="$m"
          m=
        fi
        if [[ $n ]]
        then
          BANK_SPEED[i]="$n"
          n=
        else
          BANK_SPEED[i]=''
        fi
        ;;
      esac
    elif [[ "$l" == 'Memory Device' ]]
    then
      ((x=1))
    fi
  done <<< "$(sudo /usr/sbin/dmidecode -t 17 2>/dev/null|egrep -o '[^[:cntrl:]]+')"

  ((MEM_TOTAL=0))
  for ((i=0; i<${#BANK_FORM[@]}; i++))
  do
    m="$(egrep -o '[0-9]+' <<< "${BANK_SIZE[i]}")"
    if [[ ${BANK_SIZE[i]} == *GB ]]
    then
      (( m *= 1024 ))
    elif [[ ${BANK_SIZE[i]} != *MB ]]
    then
      (( m = 0 ))
    fi
    (( MEM_TOTAL += m ))
  done

  echo 'Muistin kokonaismäärä: '"$MEM_TOTAL"' MiB'

  for ((i = 0; i < ${#MEM_BANK_FORM[@]}; i++))
  do
    echo -n "${MEM_BANK_TYPE[i]} "
    if [[ "${MEM_BANK_SIZE[i]}" == '0' ]]
    then
      echo '<tyhjä>'
    else
      echo "${MEM_BANK_SPEED[i]} ${MEM_BANK_SIZE[i]}"
    fi
  done

  return 0
}
