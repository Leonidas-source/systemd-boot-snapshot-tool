#!/bin/bash
red="\e[0;91m"
bold="\e[1m"
reset="\e[0m"
own_value() {
  ls
  echo "please set name of your config file"
  read -e name
}
set_name() {
  ls | grep $answr3 && name=$answr3.conf
  ls | grep $answr3 || own_value
}
check_id() {
  [ "$default_subvolume" == "ID 5 (FS_TREE)" ] || warning_message="WARNING: YOUR FILESYSTEM DEFAULT SUBVOLUME IS NOT CORRECT. PLEASE SET YOUR DEFAULT SUBVOLUME ID TO 5"
}
menu() {
  default_subvolume=$(btrfs subvolume get-default folder)
  check_id
  timeout=$(cat /boot/loader/loader.conf | grep timeout | sed "s/timeout //")
  clear
  echo -e "${red}${bold}$warning_message${reset}"
  echo -e "your current bootloader timeout is ${red}${bold}$timeout${reset} seconds


  "
  list=$(btrfs subvolume list folder | awk '{print $9}')
  echo -e "list of subvolumes:"
  echo -e "${red}${bold}$list${reset}




  "
  echo "What do you want to do
    1) create a snapshot and boot entry
    2) remove a snapshot and boot entry
    3) change bootloader timeout
    4) exit"
    read answr3
    [ "$answr3" == "1" ] && btrfs_managment
    [ "$answr3" == "2" ] && delete
    [ "$answr3" == "3" ] && change_timeout
    [ "$answr3" == "4" ] && quit
    [ "$answr3" == "" ] && quit
}
change_timeout() {
  clear
  echo "set your timeout in seconds"
  read seconds
  sed -i "s/timeout $timeout/timeout $seconds/" /boot/loader/loader.conf
  menu
}
quit() {
  umount folder
  clear
  exit
}
delete() {
  clear
  echo -e "${red}${bold}$list${reset}"
  echo "set subvolume to delete"
  cd folder
  read -e arg2
  cd ..
  btrfs subvolume delete -v -c folder/$arg2
  source=$(pwd)
  cd /boot/loader/entries/
  arg=$(echo "$arg2" | sed 's|/||')
  rm $arg.conf
  cd /boot
  rm -rv $arg2
  cd $source
  menu
}
error() {
  clear
  echo "You must be root to execute this script"
  exit
}
user_check() {
  user_name=$(whoami)
  [ "$user_name" == root ] || error
}
setup() {
  lsblk -f
  echo "set your btrfs partition"
  read answr
  echo "Should I save config?
  1) yes
  2) no"
  read answr2
  [ "$answr2" == "1" ] && save_config
}
save_config() {
  echo "$answr" >> config
}
btrfs_managment() {
  time=$(date +%d'-'%m'-'%Y'-'%H'-'%M'-'%S)
  ls | grep -w "folder" || mkdir folder
  clear
  echo -e "${red}${bold}$list${reset}"
  echo "set subvolume"
  cd folder
  read -e answr2
  cd ..
  clear
  echo "set name of snapshot
  1) by date
  2) manually"
  read answr
  [ "$answr" == "1" ] && (btrfs subvolume snapshot folder/$answr2 folder/$time && modify_boot)
  [ "$answr" == "2" ] && name
  menu
}
name() {
  echo "set your subvolume name"
  read name_for_snapshot
  btrfs subvolume snapshot folder/$answr2  folder/$name_for_snapshot
  modify_boot_with_own_name
}
modify_boot() {
  answr3=$(echo "$answr2" | sed 's|/||')
  source=$(pwd)
  cd /boot/loader/entries/
  count_all_configs=$(ls | wc -l)
  [ "$count_all_configs" == "1" ] && name=$(ls | grep conf)
  [ "$count_all_configs" == "1" ] || set_name
  touch $time.conf
  cat $name | grep title | cat >> $time.conf
  og_name=$(cat $name | grep title)
  sed -i "s/$og_name/title $time/g" $time.conf
  second_line=$(cat $name | grep vmlinuz | sed "s/linux//" | sed "s|/||" | sed "s/ //")
  echo "$second_line" | grep "$answr2" && second_line=$(cat $name | grep vmlinuz | sed "s/linux//" | sed "s/ //" | sed "s/$answr3//" | sed "s|//||")
  echo linux /$time/$second_line >> $time.conf
  third_line=$(cat $name | grep initramfs | sed "s/initrd//" | sed "s|/||" | sed 's/ //')
  echo "$third_line" | grep "$answr2" && third_line=$(cat $name | grep initramfs | sed "s/initrd//" | sed "s/ //" | sed "s/$answr3//" | sed "s|//||")
  echo "initrd /$time/$third_line" | cat >> $time.conf
  cat $name | grep options | cat >> $time.conf
  cat $time.conf | grep subvol && sed -i "s|rootflags=subvol=/$answr3|rootflags=subvol=/$time|" $time.conf
  cat $time.conf | grep subvol || sed -i "s|rw|rw rootflags=subvol=/$time|" $time.conf
  cd /boot
  mkdir $time
  check_for_another_folder
  replace_old_kernel_path_for_time
}
replace_old_kernel_path_for_time() {
  grep /boot/vmlinuz folder/$time/usr/share/libalpm/scripts/mkinitcpio-install || sed -i "s|/boot/$answr2/*|/boot/$time/|" folder/$time/usr/share/libalpm/scripts/mkinitcpio-install
  grep /boot/vmlinuz folder/$time/usr/share/libalpm/scripts/mkinitcpio-install && sed -i "s|/boot/*|/boot/$time/|" folder/$time/usr/share/libalpm/scripts/mkinitcpio-install
  grep /boot/vmlinuz folder/$time/usr/share/libalpm/scripts/mkinitcpio-remove || sed -i "s|/boot/$answr2/*|/boot/$time/|" folder/$time/usr/share/libalpm/scripts/mkinitcpio-remove
  grep /boot/vmlinuz folder/$time/usr/share/libalpm/scripts/mkinitcpio-remove && sed -i "s|/boot/*|/boot/$time/|" folder/$time/usr/share/libalpm/scripts/mkinitcpio-remove
  og_path=$(pwd)
  cd folder/$time/etc/mkinitcpio.d/
  kernel=$(ls | grep linux)
  grep $answr3 $kernel || sed -i "s|/boot/*|/boot/$time/|" $kernel
  grep $answr3 $kernel && sed -i "s|/boot/$answr3/|/boot/$time/|" $kernel
  cd $og_path
}
check_for_another_folder() {
  find "$answr3" && another_function
  find "$answr3" || right_function
  cd $source
}
another_function() {
  cp /boot/$answr3/*  /boot/$time/
}
right_function() {
  init=$(ls | grep initramfs | sed -n '2p')
  cp -v $init $time
  kernel=$(ls | grep vmlinuz)
  cp -v $kernel $time
}
modify_boot_with_own_name() {
  answr3=$(echo "$answr2" | sed 's|/||')
  source=$(pwd)
  cd /boot/loader/entries/
  count_all_configs=$(ls | wc -l)
  [ "$count_all_configs" == "1" ] && name=$(ls | grep conf)
  [ "$count_all_configs" == "1" ] || set_name
  touch $name_for_snapshot.conf
  cat $name | grep title | cat >> $name_for_snapshot.conf
  og_name=$(cat $name | grep title)
  sed -i "s/$og_name/title $name_for_snapshot/g" $name_for_snapshot.conf
  second_line=$(cat $name | grep vmlinuz | sed "s/linux//" | sed "s|/||" | sed "s/ //")
  echo "$second_line" | grep "$answr2" && second_line=$(cat $name | grep vmlinuz | sed "s/linux//" | sed "s/ //" | sed "s/$answr3//" | sed "s|//||")
  echo "linux /$name_for_snapshot/$second_line" >> $name_for_snapshot.conf
  third_line=$(cat $name | grep initramfs | sed "s/initrd//" | sed "s|/||" | sed 's/ //')
  echo "$third_line" | grep "$answr2" && third_line=$(cat $name | grep initramfs | sed "s/initrd//" | sed "s/ //" | sed "s/$answr3//" | sed "s|//||")
  echo "initrd /$name_for_snapshot/$third_line" | cat >> $name_for_snapshot.conf
  cat $name | grep options | cat >> $name_for_snapshot.conf
  cat $name_for_snapshot.conf | grep subvol && sed -i "s|rootflags=subvol=/$answr3|rootflags=subvol=/$name_for_snapshot|" $name_for_snapshot.conf
  cat $name_for_snapshot.conf | grep subvol || sed -i "s|rw|rw rootflags=subvol=/$name_for_snapshot|" $name_for_snapshot.conf
  cd /boot
  mkdir $name_for_snapshot
  modify_boot_with_own_name_part_one
  replace_old_kernel_path_for_own_name
}
replace_old_kernel_path_for_own_name() {
  grep /boot/vmlinuz folder/$name_for_snapshot/usr/share/libalpm/scripts/mkinitcpio-install || sed -i "s|/boot/$answr2/*|/boot/$name_for_snapshot/|" folder/$name_for_snapshot/usr/share/libalpm/scripts/mkinitcpio-install
  grep /boot/vmlinuz folder/$name_for_snapshot/usr/share/libalpm/scripts/mkinitcpio-install && sed -i "s|/boot/*|/boot/$name_for_snapshot/|" folder/$name_for_snapshot/usr/share/libalpm/scripts/mkinitcpio-install
  grep /boot/vmlinuz folder/$name_for_snapshot/usr/share/libalpm/scripts/mkinitcpio-remove || sed -i "s|/boot/$answr2/*|/boot/$name_for_snapshot/|" folder/$name_for_snapshot/usr/share/libalpm/scripts/mkinitcpio-remove
  grep /boot/vmlinuz folder/$name_for_snapshot/usr/share/libalpm/scripts/mkinitcpio-remove && sed -i "s|/boot/*|/boot/$name_for_snapshot/|" folder/$name_for_snapshot/usr/share/libalpm/scripts/mkinitcpio-remove
  og_path=$(pwd)
  cd folder/$name_for_snapshot/etc/mkinitcpio.d/
  kernel=$(ls | grep linux)
  grep $answr3 $kernel || sed -i "s|/boot/*|/boot/$name_for_snapshot/|" $kernel
  grep $answr3 $kernel && sed -i "s|/boot/$answr3/|/boot/$name_for_snapshot/|" $kernel
  cd $og_path
}
modify_boot_with_own_name_part_one() {
  ls | grep -w "$answr3" && modify_boot_with_own_name_part_two
  ls | grep -w "$answr3" || modify_boot_with_own_name_part_three
}
modify_boot_with_own_name_part_two() {
  cp -v /boot/$answr3/* /boot/$name_for_snapshot
  cd $source
}
modify_boot_with_own_name_part_three() {
  init=$(ls | grep initramfs | sed -n '2p')
  cp -v $init $name_for_snapshot
  kernel=$(ls | grep vmlinuz)
  cp -v $kernel $name_for_snapshot
  cd $source
}
user_check
find folder || mkdir folder
ls | grep -w "config" || setup
partition=$(cat config | grep /dev/)
mount -o subvolid=5 $partition folder
menu
