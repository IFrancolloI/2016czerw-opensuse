#!/bin/bash

echo "=== Rozpoczynam automatyczną konfigurację serwera openSUSE 16.0 ==="

# Zmienne przypisane do odpowiednich interfejsów (w razie potrzeby popraw eth0/eth1 na właściwe nazwy np. enp0s3)
IF_LAN1="eth0"
IF_LAN2="eth1"

# 1. Tworzenie użytkownika z przypisanym hasłem i kontem (Zadanie 13)
echo "--- Tworzenie użytkownika jkowalski ---"
useradd -m -c "Jan Kowalski" -s /bin/bash jkowalski
echo "jkowalski:zaq1@WSX" | chpasswd
# Dodanie do grupy administratorów (w Linuksie np. wheel lub utworzenie nowej grupy)
groupadd -f Administratorzy
usermod -aG Administratorzy jkowalski

# 2. Konfiguracja sieci dla LAN1 i LAN2 poprzez wpisanie profili NetworkManagera (Zadanie 6 i 7)
echo "--- Konfiguracja interfejsów LAN1 i LAN2 ---"
mkdir -p /etc/NetworkManager/system-connections

cat <<EOF > /etc/NetworkManager/system-connections/LAN1.nmconnection
[connection]
id=LAN1
type=ethernet
interface-name=$IF_LAN1

[ipv4]
method=manual
address1=10.0.0.2/24,10.0.0.1
dns=8.8.8.8;
EOF

cat <<EOF > /etc/NetworkManager/system-connections/LAN2.nmconnection
[connection]
id=LAN2
type=ethernet
interface-name=$IF_LAN2

[ipv4]
method=manual
address1=10.0.1.2/24
EOF

# Uprawnienia dla NetworkManagera
chmod 600 /etc/NetworkManager/system-connections/LAN1.nmconnection
chmod 600 /etc/NetworkManager/system-connections/LAN2.nmconnection

nmcli connection reload
nmcli connection up LAN1
nmcli connection up LAN2

# 3. Konfiguracja rutingu i NAT - Firewalld (Zadanie 8)
echo "--- Włączanie rutingu (IP Forwarding) oraz NAT ---"
# Automatyczne dodanie parametru do sysctl
cat <<EOF > /etc/sysctl.d/99-ipforward.conf
net.ipv4.ip_forward = 1
EOF
sysctl -p /etc/sysctl.d/99-ipforward.conf

# Przeniesienie interfejsów do odpowiednich stref i włączenie maskarady w strefie external/publicznej
firewall-cmd --permanent --zone=external --add-interface=$IF_LAN1
firewall-cmd --permanent --zone=internal --add-interface=$IF_LAN2
firewall-cmd --permanent --zone=external --add-masquerade
firewall-cmd --reload

# 4. Instalacja i konfiguracja DHCP dla sieci LAN2 (Zadanie 9)
echo "--- Konfiguracja usługi DHCP Server ---"
# Sprawdzenie, czy DHCP jest zainstalowane (jesli nie - zainstaluj za pomocą zypper)
zypper install -y dhcp-server

cat <<EOF > /etc/dhcpd.conf
option domain-name "egzamin.local";
option domain-name-servers 8.8.8.8, 8.8.4.4;
default-lease-time 600;
max-lease-time 7200;
authoritative;

subnet 10.0.1.0 netmask 255.255.255.0 {
  range 10.0.1.10 10.0.1.100;
  option routers 10.0.1.2;
}
EOF

# Ustawienie interfejsu dla usługi DHCP
sed -i "s/^DHCPD_INTERFACE=.*/DHCPD_INTERFACE=\"$IF_LAN2\"/" /etc/sysconfig/dhcpd

systemctl enable --now dhcpd

# 5. Konfiguracja folderu udostępnionego Samba (Zadanie 14 i 15)
echo "--- Konfiguracja udostępniania katalogu C:\dane (Samba) ---"
zypper install -y samba

mkdir -p /srv/samba/dane
chown root:Administratorzy /srv/samba/dane

# Nadawanie uprawnień systemowych ACL
setfacl -m g:Administratorzy:rwx,d:g:Administratorzy:rwx /srv/samba/dane
setfacl -m u:jkowalski:rwx,d:u:jkowalski:rwx /srv/samba/dane

# Automatyczne doklejenie do istniejącego pliku smb.conf bloku z nowym zasobem
cat <<EOF >> /etc/samba/smb.conf

[dane]
    path = /srv/samba/dane
    read only = no
    browsable = yes
    valid users = @Administratorzy jkowalski
    write list = @Administratorzy jkowalski
    force group = Administratorzy
    create mask = 0770
    directory mask = 0770
EOF

# Dodanie użytkownika Samba (hasło trzeba będzie potwierdzić ręcznie, lub wygenerować hashem, tu wersja półautomatyczna)
(echo "zaq1@WSX"; echo "zaq1@WSX") | smbpasswd -s -a jkowalski

# Start Samby
systemctl enable --now smb nmb
firewall-cmd --permanent --zone=internal --add-service=samba
firewall-cmd --reload

echo "=== Konfiguracja zakończona pomyślnie! ==="