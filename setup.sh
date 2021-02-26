#!/bin/bash

touch /tmp/cloud-config-ausgeführt

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
  --hcloud-token)
    TOKEN="$2"
    shift
    shift
  ;;
  --whitelisted-ips)
    WHITELIST_S="$2"
    shift
    shift
  ;;
  --floating-ips)
    FLOATING_IPS="--floating-ips"
    shift
  ;;
  *)
    shift
  ;;
esac
done

FLOATING_IPS=${FLOATING_IPS:-""}


sed -i 's/[#]*PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/[#]*PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

systemctl restart sshd

wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
chmod +x jq-linux64
mv jq-linux64 /usr/local/bin/jq


curl -o /usr/local/bin/update-config.sh https://raw.githubusercontent.com/vitobotta/hetzner-cloud-init/master/update-config.sh

chmod +x /usr/local/bin/update-config.sh

ufw allow proto tcp from any to any port 80,443

IFS=', ' read -r -a WHITELIST <<< "$WHITELIST_S"

for IP in "${WHITELIST[@]}"; do
  ufw allow from "$IP"
done

ufw allow from 10.43.0.0/16
ufw allow from 10.42.0.0/16
ufw allow from 10.0.0.0/16 # default private network cidr
ufw allow from 10.244.0.0/16 # in case we use the default cidr expected by the cloud controller manager

ufw -f default deny incoming
ufw -f default allow outgoing

ufw -f enable

cat <<EOF >> /etc/crontab
* * * * * root /usr/local/bin/update-config.sh --hcloud-token ${TOKEN} --whitelisted-ips ${WHITELIST_S} ${FLOATING_IPS}
EOF

/usr/local/bin/update-config.sh --hcloud-token ${TOKEN} --whitelisted-ips ${WHITELIST_S} ${FLOATING_IPS}

## Swap Speicher 
dd if=/dev/zero of=/swapfile bs=4096 count=1048576
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
cat <<EOF >> /etc/fstab
/swapfile swap swap defaults 0 0
EOF

## SSH Keys
cat <<EOF >> /root/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDmQA62u8sW/22SidvYWILnbf8z3u1cHQPzjyyVOU0KQnmGg/t+LiAQTpGN7SmyBBgvHbmPfoGBdTQPkP4qyY6+yvzhekrKVo+c/jxTwVRG4vm2yNFNvihSeVC9LLCSuQBGOyCSxOaK4L/v1SZ29YPwBFZNIqVGGmJX6QlTXx+YFrUyiS+lup73vAJQ5Y/8iEHdI0DHLPMyjsb7GMLWtX03Zo5gaz2bFfl5i7mgdaFGN6aaNjpDHq/oMaqvVxqCKOlblOYor7Sdse900ZT2kjWL8+loNU4eEuddwQ26fqGE6+JY9DZtbGNkqPm+GA+mLHSHmAZUg1f3sHpK2o1yugmcsSugFcObpbQ92nmu0sN64txic4xH0ukvPz4ursxzoEdZt9q2Wz2aZD/FoAhVgvq2zboBQAjRM/6vd39IyQJAnK5lgBwDq0TdtBHpRo4+CJyOA4NoqWn1qeOOU33KnjNqYi4u0nH52NCa/41diOD5EcSRXCdBCxJ8ETosn1L8EOU= root@hetzner01
EOF

## DNS
cat <<EOF >> /etc/hosts
10.0.0.2 rancher.notitia-technologies.de
EOF

