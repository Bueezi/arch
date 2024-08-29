#!/bin/bash

# Set variables
HOSTNAME="arch"               # Hostname
USERNAME="ben"                # Username
PASSWORD="mynameislol"        # Password for both root and user
LOCALE="en_US.UTF-8"          # Locale
KEYMAP="be-latin1"            # Keyboard layout
TIMEZONE="Europe/Brussels"    # Timezone

# Install base system and necessary packages
echo "Installing base system..."
pacstrap /mnt base base-devel linux linux-firmware vim sudo networkmanager grub efibootmgr

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

# Set the hostname
echo "Setting hostname..."
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" >> /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Set root password
echo "Setting root password..."
echo "root:$PASSWORD" | chpasswd

# Create new user with the same password
echo "Creating user $USERNAME..."
useradd -m -G wheel $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers

# Enable essential services
echo "Enabling NetworkManager..."
systemctl enable NetworkManager

# Install and configure GRUB
echo "Installing GRUB..."
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

EOF

# Unmount partitions and reboot
echo "Unmounting partitions..."
umount -R /mnt

echo "Installation complete! Rebooting..."
reboot
