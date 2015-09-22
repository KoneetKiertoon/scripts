RUNNAME="GRUB reinstall"
RUNASROOT=1

runfile_exec()
{
  sudo apt-get install --reinstall grub-pc
  return $?
}
