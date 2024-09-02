#!/bin/bash

# Function to prompt for disk selection
select_disk() {
    disks=($(lsblk -nd --output NAME,SIZE,TYPE | grep disk | awk '{print $1 " (" $2 ")"}'))
    echo "Available disks:"
    for i in "${!disks[@]}"; do
        echo "$i) ${disks[$i]}"
    done
    read -p "Select a disk by number: " disk_index
    selected_disk="/dev/$(echo ${disks[$disk_index]} | awk '{print $1}')"
    echo "You selected $selected_disk"
}

# Function to prompt for swap size
get_swap_size() {
    read -p "Enter swap size in GB (enter 0 for no swap): " swap_size
}

# Prompt for disk selection and swap size
select_disk
get_swap_size

# Determine partition suffix (e.g., 'p' for mmcblk1, none for sda)
if [[ $selected_disk =~ mmcblk[0-9] ]]; then
    part_suffix="p"
else
    part_suffix=""
fi
