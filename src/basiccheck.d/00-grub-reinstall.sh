RUNNAME="GRUB"
RUNASROOT=1

runfile_exec()
{
  sudo apt-get install --reinstall grub-pc
  return $?
}
