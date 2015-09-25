RUNNAME="GRUB"
RUNASROOT=1

runfile_exec()
{
  clear
  sudo apt-get install --reinstall grub-pc
  return $?
}
