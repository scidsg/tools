#!/bin/bash

# Welcome message and ASCII art
cat << "EOF"
 ________    ___      ________      ________      ___  ___      ________       ________     
|\   __  \  |\  \    |\   __  \    |\   __  \    |\  \|\  \    |\   ___  \    |\   ___ \    
\ \  \|\  \ \ \  \   \ \  \|\ /_   \ \  \|\  \   \ \  \\\  \   \ \  \\ \  \   \ \  \_|\ \   
 \ \   ____\ \ \  \   \ \   __  \   \ \  \\\  \   \ \  \\\  \   \ \  \\ \  \   \ \  \ \\ \  
  \ \  \___|  \ \  \   \ \  \|\  \   \ \  \\\  \   \ \  \\\  \   \ \  \\ \  \   \ \  \_\\ \ 
   \ \__\      \ \__\   \ \_______\   \ \_______\   \ \_______\   \ \__\\ \__\   \ \_______\
    \|__|       \|__|    \|_______|    \|_______|    \|_______|    \|__| \|__|    \|_______|
                                                                                            
🤫 A free tool by Science & Design - https://scidsg.org
Pibound: Automatically set up Pi-hole and Unbound

EOF
sleep 3

set -e

# Install Pi-hole
curl -sSL https://install.pi-hole.net | bash

# Ensure the script is being run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Install Unbound
sudo apt install -y unbound

# Check if Unbound installation was successful
if [ $? -eq 0 ]; then
    echo "Unbound installed successfully"
else
    echo "Unbound installation failed"
    exit 1
fi

# Optional: Download root hints file
wget https://www.internic.net/domain/named.root -qO- | tee /var/lib/unbound/root.hints

# Create the configuration for unbound
cat > /etc/unbound/unbound.conf.d/pi-hole.conf << EOF
server:
    # If no logfile is specified, syslog is used
    # logfile: "/var/log/unbound/unbound.log"
    verbosity: 1

    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes

    # May be set to yes if you have IPv6 connectivity
    do-ip6: no

    # You want to leave this to no unless you have *native* IPv6. With 6to4 and
    # Terredo tunnels your web browser should favor IPv4 for the same reasons
    prefer-ip6: no

    # Use this only when you downloaded the list of primary root servers!
    # If you use the default dns-root-data package, unbound will find it automatically
    #root-hints: "/var/lib/unbound/root.hints"

    # Trust glue only if it is within the server's authority
    harden-glue: yes

    # Require DNSSEC data for trust-anchored zones, if such data is absent, the zone becomes BOGUS
    harden-dnssec-stripped: yes

    # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
    use-caps-for-id: no

    # Reduce EDNS reassembly buffer size.
    # IP fragmentation is unreliable on the Internet today, and can cause
    # transmission failures when large DNS messages are sent via UDP. Even
    # when fragmentation does work, it may not be secure; it is theoretically
    # possible to spoof parts of a fragmented DNS message, without easy
    # detection at the receiving end. Recently, there was an excellent study
    # >>> Defragmenting DNS - Determining the optimal maximum UDP response size for DNS <<<
    # by Axel Koolhaas, and Tjeerd Slokker (https://indico.dns-oarc.net/event/36/contributions/776/)
    # in collaboration with NLnet Labs explored DNS using real world data from the
    # the RIPE Atlas probes and the researchers suggested different values for
    # IPv4 and IPv6 and in different scenarios. They advise that servers should
    # be configured to limit DNS messages sent over UDP to a size that will not
    # trigger fragmentation on typical network links. DNS servers can switch
    # from UDP to TCP when a DNS response is too big to fit in this limited
    # buffer size. This value has also been suggested in DNS Flag Day 2020.
    edns-buffer-size: 1232

    # Perform prefetching of close to expired message cache entries
    # This only applies to domains that have been frequently queried
    prefetch: yes

    # One thread should be sufficient, can be increased on beefy machines. In reality for most users running on small networks or on a single machine, it should be unnecessary to seek performance enhancement by increasing num-threads above 1.
    num-threads: 1

    # Ensure kernel buffer is large enough to not lose messages in traffic spikes
    so-rcvbuf: 1m

    # Ensure privacy of local IP ranges
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10
EOF

# Restart unbound and test it
service unbound restart
dig pi-hole.net @127.0.0.1 -p 5335

# Set edns-packet-max
echo 'edns-packet-max=1232' > /etc/dnsmasq.d/99-edns.conf

# Test validation with retry logic
for i in {1..3}; do
    echo "Attempt $i to resolve fail01.dnssec.works..."
    dig fail01.dnssec.works @127.0.0.1 -p 5335 && break || sleep 3
done

for i in {1..3}; do
    echo "Attempt $i to resolve dnssec.works..."
    dig dnssec.works @127.0.0.1 -p 5335 && break || sleep 3
done

# Debian Bullseye+ releases auto-install a package called openresolv with a certain 
# configuration that will cause unexpected behaviour for pihole and unbound. The effect 
# is that the unbound-resolvconf.service instructs resolvconf to write unbound's own 
# DNS service at nameserver 127.0.0.1 , but without the 5335 port, into the file 
# /etc/resolv.conf. That /etc/resolv.conf file is used by local services/processes to 
# determine DNS servers configured. You need to edit the configuration file and disable 
# the service to work-around the misconfiguration.

# Disable unbound-resolvconf.service
systemctl disable --now unbound-resolvconf.service

# Disable resolvconf_resolvers.conf
sed -Ei 's/^unbound_conf=/#unbound_conf=/' /etc/resolvconf.conf
FILE=/etc/unbound/unbound.conf.d/resolvconf_resolvers.conf
if [ -f "$FILE" ]; then
    rm $FILE
else 
    echo "$FILE does not exist"
fi

# Set up logging for unbound
mkdir -p /var/log/unbound
touch /var/log/unbound/unbound.log
chown unbound /var/log/unbound/unbound.log

sudo service unbound restart

# Update root hints every 6 months
(crontab -l 2>/dev/null; echo "0 0 1 */6 * wget https://www.internic.net/domain/named.root -qO- | tee /var/lib/unbound/root.hints >/dev/null 2>&1") | crontab -

# Inform user to manually update Pi-hole configuration
whiptail --title "Configure Pi-hole" --msgbox "Now let's update your Pi-hole DNS settings.\n\n1. Log in to Pi-hole\n\n2. Click Settings > DNS\n\n3. Uncheck any upstream servers currently selected.\n\n4. Select Custom 1 (IPv4) and enter 127.0.0.1#5335.\n\n" 16 64
whiptail --title "Configure Router" --msgbox "Finally, you need to update your router's settings to use your Pi-hole for its DNS server. All routers are different, so please refer to your specific model's istructions.\n\n" 16 64

echo "
✅ Installation complete!
                                               
Pi-hole Bundle Installer is a product by Science & Design. 
Learn more about us at https://scidsg.org.
Have feedback? Send us an email at feedback@scidsg.org."