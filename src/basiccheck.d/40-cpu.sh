RUNNAME="CPU"

runfile_exec()
{
  local MODEL CORES MAXMHZ

  MODEL="$(grep '^model name' /proc/cpuinfo|sort -u|sed -r 's|^[^:]+:[[:blank:]]*||')"
  CORES="$(grep '^cpu cores' /proc/cpuinfo|sort -u|sed -r 's|^[^:]+:[[:blank:]]*||')"
  MAXMHZ="$(cpufreq-info -l|cut -d ' ' -f 2|sed -r 's/([0-9]{3})$/.\1/')"

  echo "CPU model: $MODEL"$'\n'"CPU cores: $CORES"$'\n'"Max speed: $MAXMHZ MHz"
  return 0
}
