#!/bin/bash

echo "=== Rozpoczynam automatyczną konfigurację stacji roboczej openSUSE 16.0 ==="

# 1. Konfiguracja sieci (Zadanie 10)
# Pobieranie adresu IPv4 i DNS automatycznie (DHCP) dla interfejsu (np. eth0/enp0s3)
IF_CLIENT="eth0"

echo "--- Konfiguracja klienta DHCP na interfejsie $IF_CLIENT ---"
mkdir -p /etc/NetworkManager/system-connections

cat <<EOF > /etc/NetworkManager/system-connections/SiecKliencka.nmconnection
[connection]
id=SiecKliencka
type=ethernet
interface-name=$IF_CLIENT

[ipv4]
method=auto
EOF

chmod 600 /etc/NetworkManager/system-connections/SiecKliencka.nmconnection
nmcli connection reload
nmcli connection up SiecKliencka

# 2. Zmiana hasła administratora i utworzenie pliku (Zadania 4 i 11)
echo "--- Ustawianie hasła roota (Administratora) i pliku z haslem ---"
echo "root:Q@wertyuiop" | chpasswd

# Tworzenie pliku haslo.txt na pulpicie roota (w openSUSE root rzadko ma klasyczny pulpit, 
# więc tworzymy folder Desktop, jeśli nie istnieje)
mkdir -p /root/Desktop
echo "Login: admin" > /root/Desktop/haslo.txt
echo "Hasło: tajne_haslo_rutera" >> /root/Desktop/haslo.txt

# 3. Utworzenie użytkownika jkowalski (Zadanie 13)
echo "--- Tworzenie konta jkowalski na stacji roboczej ---"
useradd -m -c "Jan Kowalski" -s /bin/bash jkowalski
echo "jkowalski:zaq1@WSX" | chpasswd
# Jeśli uzywamy interfejsu GUI (KDE/GNOME), katalog domowy jest tworzony przez '-m'

# 4. Automatyczne mapowanie zasobu sieciowego Samby (Zadanie 16)
# Zamiast litery dysku "K:" (typowej dla Windowsa), w Linuksie robimy tzw. podmontowanie 
# zasobu cifs pod określony folder np. /mnt/K 
echo "--- Konfiguracja mapowania dysku (CIFS/Samba) ---"
zypper install -y cifs-utils

mkdir -p /mnt/K
chown jkowalski:users /mnt/K

# Tworzenie ukrytego pliku z poświadczeniami
cat <<EOF > /home/jkowalski/.smbcredentials
username=jkowalski
password=zaq1@WSX
domain=WORKGROUP
EOF
chmod 600 /home/jkowalski/.smbcredentials
chown jkowalski:users /home/jkowalski/.smbcredentials

# Automatyczne dodanie wpisu do /etc/fstab, aby dysk "mapował się" przy starcie
# Zakładamy, że IP serwera (z poprzedniego zadania na interfejsie LAN2) to 10.0.1.2
if ! grep -q "10.0.1.2/dane" /etc/fstab; then
    echo "//10.0.1.2/dane /mnt/K cifs credentials=/home/jkowalski/.smbcredentials,uid=jkowalski,gid=users,rw,iocharset=utf8,sec=ntlmssp 0 0" >> /etc/fstab
fi

# Zmontowanie dysków bez restartowania komputera
mount -a

echo "=== Konfiguracja stacji roboczej zakończona pomyślnie! ==="
