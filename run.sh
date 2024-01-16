#!/usr/bin/env sh

# $1 = domain
# $2 = port
# $3 = webroot path
# $4 = php executable
# $5 = owner
# $6 = group
# $7 = octal permissions

echo "Changing to webroot $3"
cd "$3"

echo "Creating the PHP file"
echo "<?php if ( function_exists( 'opcache_reset' ) ) { opcache_reset(); }" > opcache_reset.php

if [ -z "$5" ]
then
    echo "User provided, running chown to $5"
    chown $5 opcache_reset.php
else
    echo "Relying on default user"
fi

if [ -z "$6" ] 
then
    echo "Group provided, running chgrp to $6"
    chgrp $6 opcache_reset.php
else
    echo "Relying on default group"
fi

echo "Setting permissions"
chmod $7 opcache_reset.php

echo "Running via CLI, just in case in use"
$4 opcache_reset.php

echo "Running via HTTP"
curl "$1/opcache_reset.php:$2" --resolve "$1:$2:127.0.0.1"

echo "Removing PHP script"
rm opcache_reset.php
