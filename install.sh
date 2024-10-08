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

# Set variables
HOSTNAME="arch"               # Hostname
USERNAME="ben"                # Username
PASSWORD="mynameislol"        # Password for both root and user
LOCALE="en_US.UTF-8"          # Locale
KEYMAP="be-latin1"            # Keyboard layout
TIMEZONE="Europe/Brussels"    # Timezone

# Partition the disk
echo "Partitioning the disk $selected_disk..."
parted -s "$selected_disk" mklabel gpt
parted -s "$selected_disk" mkpart primary fat32 1MiB 101MiB
parted -s "$selected_disk" set 1 esp on

if [ "$swap_size" -ne 0 ]; then
    parted -s "$selected_disk" mkpart primary linux-swap 101MiB "$((101 + swap_size * 1024))MiB"
    parted -s "$selected_disk" mkpart primary ext4 "$((101 + swap_size * 1024))MiB" 100%
else
    parted -s "$selected_disk" mkpart primary ext4 101MiB 100%
fi

# Format the partitions
echo "Formatting the partitions..."
mkfs.fat -F32 "${selected_disk}${part_suffix}1"
if [ "$swap_size" -ne 0 ]; then
    mkswap "${selected_disk}${part_suffix}2"
    swapon "${selected_disk}${part_suffix}2"
fi
mkfs.ext4 "${selected_disk}${part_suffix}3"

# Mount the partitions
echo "Mounting the partitions..."
mount "${selected_disk}${part_suffix}3" /mnt
mkdir -p /mnt/boot/efi
mount "${selected_disk}${part_suffix}1" /mnt/boot/efi

# Install base system and necessary packages
echo "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware sudo networkmanager grub efibootmgr kitty vim sddm i3-wm i3status feh dmenu curl thunar bluez blueman network-manager-applet firefox git

# Generate fstab
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the system
echo "Entering chroot environment..."
arch-chroot /mnt /bin/bash <<EOF

# Set the timezone
echo "Setting timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set the locale
echo "Setting locale..."
echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Set the keyboard layout
echo "Setting keyboard layout..."
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Set the X11 keymap
mkdir -p /etc/X11/xorg.conf.d
cat <<EOL > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
    Identifier "keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "be"
    Option "XkbVariant" "latin1"
EndSection
EOL


# Set the hostname
echo "Setting hostname..."
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Set root password
echo "Setting root password..."
echo "root:$PASSWORD" | chpasswd


# Create a new user with the specified username and password
useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd
# Add user to the wheel group for sudo privileges
usermod -aG wheel "$USERNAME"
# Ensure sudoers file allows wheel group members to use sudo
grep -q "^%wheel" /etc/sudoers || echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers


# Enable essential services
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable sddm

# Install and configure GRUB
echo "Installing GRUB..."
grub-install "$selected_disk"

# Generate GRUB configuration with no timeout
echo "Generating GRUB configuration..."
grub-mkconfig -o /boot/grub/grub.cfg
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
sed -i 's/^GRUB_HIDDEN_TIMEOUT=.*/GRUB_HIDDEN_TIMEOUT=0/' /etc/default/grub

# Download i3 and i3status configuration files
echo "Downloading i3 configuration..."
mkdir -p /home/$USERNAME/.config/i3
curl -o /home/$USERNAME/.config/i3/config https://raw.githubusercontent.com/Bueezi/arch/main/config
chown $USERNAME:$USERNAME /home/$USERNAME/.config/i3/config

echo "Downloading i3status configuration..."
curl -o /home/$USERNAME/.i3status.conf https://raw.githubusercontent.com/Bueezi/arch/main/.i3status.conf
chown $USERNAME:$USERNAME /home/$USERNAME/.i3status.conf

# Download wallpapers
echo "Downloading wallpapers..."
mkdir -p /home/$USERNAME/Pictures
git clone --depth 1 https://github.com/Bueezi/arch.git /tmp/arch-repo
cp -r /tmp/arch-repo/wallpapers/* /home/$USERNAME/Pictures/
chown -R $USERNAME:$USERNAME /home/$USERNAME/Pictures/
rm -rf /tmp/arch-repo

EOF

# Unmount partitions
echo "Unmounting partitions..."
umount -R /mnt

# Prompt for reboot
echo -e "Installation complete! Press any key to reboot, or press ESC to exit the script."
read -rsn1 input
if [ "$input" = $'\e' ]; then
    echo "Exiting script. You can reboot manually later."
    exit 0
else
    echo "Rebooting now..."
    reboot
fi
