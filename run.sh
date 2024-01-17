#!/usr/bin/env sh

# $1 = domain
# $2 = port
# $3 = webroot path
# $4 = php executable
# $5 = owner
# $6 = group
# $7 = octal permissions
# $8 = ssh user
# $9 = ssh host
# $10 = ssh port
# $11 = ssh key

echo "Here's what we've got..."
echo "Domain: $1"
echo "Port: $2"
echo "Webroot: $3"
echo "PHP Executable: $4"
echo "Owner: $5"
echo "Group: $6"
echo "Octal Permissions: $7"
echo "SSH User: $8"
echo "SSH Host: $9"
echo "SSH Port: ${10}"
echo "SSH Key: ${11}"

echo "Preparing SSH..."
echo "${11}" > repo_private_key
#set permissions on private keys to avoid unprotected private key file error
chmod 600 repo_private_key
#create ssh directory and known_hosts file
mkdir -p ~/.ssh/ && touch ~/.ssh/known_hosts
#run ssh-keyscan to add host to known_hosts
ssh-keyscan -H $9 >> ~/.ssh/known_hosts
echo "Preparing SSH agent forwards..."
eval $(ssh-agent -s)
ssh-add repo_private_key
echo "SSH prepared!"

echo "Creating the local PHP file"
echo "<?php if ( function_exists( 'opcache_reset' ) ) { opcache_reset(); }" > opcache_reset.php

echo "Copying to server"
scp -P ${10} -i repo_private_key ./opcache_reset.php $8@$9:$3/opcache_reset.php

if [ -z "$5" ]
then
    echo "User provided, running chown to $5"
    ssh -p ${10} -i repo_private_key $8@$9 "chown $5 opcache_reset.php"
else
    echo "Relying on default user"
fi

if [ -z "$6" ] 
then
    echo "Group provided, running chgrp to $6"
    ssh -p ${10} -i repo_private_key $8@$9 "chgrp $6 opcache_reset.php"
else
    echo "Relying on default group"
fi

echo "Setting permissions"
ssh -p ${10} -i repo_private_key $8@$9 "chmod $7 opcache_reset.php"

echo "Running via CLI, just in case in use"
ssh -p ${10} -i repo_private_key $8@$9 "$4 $3/opcache_reset.php"

echo "Running via HTTP"
ssh -p ${10} -i repo_private_key $8@$9 "curl '$1/opcache_reset.php:$2' --resolve '$1:$2:127.0.0.1'"

echo "Removing PHP script"
ssh -p ${10} -i repo_private_key $8@$9 "rm $3/opcache_reset.php"
