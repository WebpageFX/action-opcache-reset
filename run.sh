#!/usr/bin/env sh

# $1 = domain
# $2 = webroot path
# $3 = php executable
# $4 = owner
# $5 = group
# $6 = octal permissions
# $7 = ssh user
# $8 = ssh host
# $9 = ssh port
# ${10} = ssh key

domain=$1
webroot_path=$2
if [ -z $3 ]
then
    php_executable="php"
else
    php_executable=$3
fi
owner=$4
group=$5
octal_permissions=$6
ssh_user=$7
ssh_host=$8
ssh_port=$9
ssh_key=${10}

echo "Here's what we've got..."
echo "Domain: $domain"
echo "Webroot: $webroot_path"
echo "PHP Executable: $php_executable"
echo "Owner: $owner"
echo "Group: $group"
echo "Octal Permissions: $octal_permissions"
echo "SSH User: $ssh_user"
echo "SSH Host: $ssh_host"
echo "SSH Port: $ssh_port"
echo "SSH Key: $ssh_key"

echo "Preparing SSH..."
echo "$ssh_key" > repo_private_key
echo "Setting key permissions"
#set permissions on private keys to avoid unprotected private key file error
chmod 600 repo_private_key
echo "Running ssh-keyscan and writing to known_hosts"
#run ssh-keyscan to add host to known_hosts
ssh-keyscan -p $ssh_port -H $ssh_host > /etc/ssh/ssh_known_hosts
echo "Preparing SSH agent forwards..."
eval $(ssh-agent -s)
echo "Adding key to SSH"
ssh-add repo_private_key
echo "SSH prepared!"

echo "Creating the local PHP file"
echo "<?php if ( function_exists( 'opcache_reset' ) ) { opcache_reset(); echo 'Opcache Reset!'; } else { echo 'Failed to reset opcache'; }" > opcache_reset.php

echo "Copying to server"
scp -o ForwardAgent=yes -P $ssh_port -i repo_private_key ./opcache_reset.php $ssh_user@$ssh_host:$webroot_path/opcache_reset.php

if [ -z "$owner" ]
then
    echo "User provided, running chown to $owner"
    ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "chown $owner $webroot_path/opcache_reset.php"
else
    echo "Relying on default user"
fi

if [ -z "$group" ] 
then
    echo "Group provided, running chgrp to $group"
    ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "chgrp $group $webroot_path/opcache_reset.php"
else
    echo "Relying on default group"
fi

echo "Setting permissions"
ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "chmod $octal_permissions $webroot_path/opcache_reset.php"

echo "Running via CLI, just in case in use"
ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "$php_executable $webroot_path/opcache_reset.php"

echo "Running via HTTP"
echo "URL: $domain/opcache_reset.php"
result=$(ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "curl '$domain/opcache_reset.php' --resolve '$domain:127.0.0.1'")

echo "Result: $result"

echo "Removing PHP script"
ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "rm $webroot_path/opcache_reset.php"
