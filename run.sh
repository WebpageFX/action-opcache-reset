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

if [ -z $3 ]
then
    php_executable="php"
else
    php_executable=$3
fi

echo "Here's what we've got..."
echo "Domain: $1"
echo "Webroot: $2"
echo "PHP Executable: $php_executable"
echo "Owner: $4"
echo "Group: $5"
echo "Octal Permissions: $6"
echo "SSH User: $7"
echo "SSH Host: $8"
echo "SSH Port: $9"
echo "SSH Key: ${10}"

echo "Preparing SSH..."
echo "${10}" > repo_private_key
echo "Setting key permissions"
#set permissions on private keys to avoid unprotected private key file error
chmod 600 repo_private_key
echo "Running ssh-keyscan and writing to known_hosts"
#run ssh-keyscan to add host to known_hosts
ssh-keyscan -p $9 -H $8 > /etc/ssh/ssh_known_hosts
echo "Preparing SSH agent forwards..."
eval $(ssh-agent -s)
echo "Adding key to SSH"
ssh-add repo_private_key
echo "SSH prepared!"

echo "Creating the local PHP file"
echo "<?php if ( function_exists( 'opcache_reset' ) ) { opcache_reset(); echo 'Opcache Reset!'; } else { echo 'Failed to reset opcache'; }" > opcache_reset.php

echo "Copying to server"
scp -o ForwardAgent=yes -P $9 -i repo_private_key ./opcache_reset.php $7@$8:$2/opcache_reset.php

if [ -z "$4" ]
then
    echo "User provided, running chown to $4"
    ssh -p $9 -i repo_private_key $7@$8 "chown $4 $2/opcache_reset.php"
else
    echo "Relying on default user"
fi

if [ -z "$5" ] 
then
    echo "Group provided, running chgrp to $5"
    ssh -p $9 -i repo_private_key $7@$8 "chgrp $5 $2/opcache_reset.php"
else
    echo "Relying on default group"
fi

echo "Setting permissions"
ssh -p $9 -i repo_private_key $7@$8 "chmod $6 $2/opcache_reset.php"

echo "Running via CLI, just in case in use"
ssh -p $9 -i repo_private_key $7@$8 "$php_executable $2/opcache_reset.php"

echo "Running via HTTP"
echo "URL: $1/opcache_reset.php"
result=$(ssh -p $9 -i repo_private_key $7@$8 "curl '$1/opcache_reset.php' --resolve '$1:127.0.0.1'")

echo "Result: $result"

echo "Removing PHP script"
ssh -p $9 -i repo_private_key $7@$8 "rm $2/opcache_reset.php"
