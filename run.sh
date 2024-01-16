#!/usr/bin/env sh

# $1 = domain
# $2 = port
# $3 = webroot path
# $4 = php executable
# $5 = owner
# $6 = group
# $7 = octal permissions

echo "Here's what we've got...\n"
echo "Domain: $1\n"
echo "Port: $2\n"
echo "Webroot: $3\n"
echo "PHP Executable: $4\n"
echo "Owner: $5\n"
echo "Group: $6\n"
echo "Octal Permissions: $7\n"

echo "Creating the local PHP file"
echo "<?php if ( function_exists( 'opcache_reset' ) ) { opcache_reset(); }" > opcache_reset.php

echo "Copying to server"
# scp ./opcache_reset.php user@target:$3/opcache_reset.php

if [ -z "$5" ]
then
    echo "User provided, running chown to $5"
    # ssh user@target "chown $5 opcache_reset.php"
else
    echo "Relying on default user"
fi

if [ -z "$6" ] 
then
    echo "Group provided, running chgrp to $6"
    # ssh user@target "chgrp $6 opcache_reset.php"
else
    echo "Relying on default group"
fi

echo "Setting permissions"
# ssh user@target "chmod $7 opcache_reset.php"

echo "Running via CLI, just in case in use"
# ssh user@target "$4 $3/opcache_reset.php"

echo "Running via HTTP"
# ssh user@target "curl '$1/opcache_reset.php:$2' --resolve '$1:$2:127.0.0.1'"

echo "Removing PHP script"
# ssh user@target rm $3/opcache_reset.php
