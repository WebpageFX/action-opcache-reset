#!/usr/bin/env sh

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
attempts_opcache_reset_http=${11}
attempts_opcache_reset_cli=${12}
attempts_opcache_reset_http_delay=${13}
attempts_opcache_reset_cli_delay=${14}


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
echo "Attempts Opcache Reset HTTP: $attempts_opcache_reset_http"
echo "Attempts Opcache Reset CLI: $attempts_opcache_reset_cli"
echo "Attempts Opcache Reset HTTP Delay: $attempts_opcache_reset_http_delay"
echo "Attempts Opcache Reset CLI Delay: $attempts_opcache_reset_cli_delay"

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
echo "<?php if ( function_exists( 'opcache_reset' ) ) { echo opcache_reset() ? 'Opcache Reset!' : 'Failed to reset opcache'; } else { echo 'Not using opcache'; }" > opcache_reset.php

copy_opcache_reset_file() {
    echo "Copying opcache_reset.php to $ssh_host"
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
}

remove_opcache_reset_file() {
    echo "Removing opcache_reset.php from $ssh_host"
    ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "rm $webroot_path/opcache_reset.php"
}


echo "Running via CLI, just in case in use"
opcache_reset_cli() {
    cli_exit_code=0
    cli_result=$(ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "$php_executable $webroot_path/opcache_reset.php")
    cli_status=$?
    if [ "$cli_result" = 'Failed to reset opcache' ]; then
        echo "FAILED TO RESET OPCACHE. RESET MANUALLY FOR CHANGES TO TAKE EFFECT"
        cli_exit_code=1
    elif [ "$cli_result" = 'No input file specified.' ]; then
        echo "FAILED TO RESET OPCACHE. RESET MANUALLY FOR CHANGES TO TAKE EFFECT"
        cli_exit_code=1
    elif [ $cli_status -ne 0 ]; then
        echo "FAILED TO RESET OPCACHE. RESET MANUALLY FOR CHANGES TO TAKE EFFECT"
        cli_exit_code=1
    fi
    echo "CLI Result: $cli_result"
    return $cli_exit_code
}
# Retry the CLI request if it fails
cli_result=""
cli_status=0
for i in $(seq 1 "$attempts_opcache_reset_cli"); do
    echo "Attempting CLI request $i of $attempts_opcache_reset_cli"
    copy_opcache_reset_file
    # Capture the result and exit code of the function
    cli_result=$(opcache_reset_cli)
    # If the function exits with a 0 status code, we're good
    cli_status=$?
    remove_opcache_reset_file
    if [ $cli_status -eq 0 ]; then
        break
    fi
    echo "Sleeping for $attempts_opcache_reset_cli_delay seconds"
    sleep $attempts_opcache_reset_cli_delay
done

# We haven't encountered a situation where the CLI using opcache was an issue, so if it fails, it's *probably* not the end of the world and not worth failing the job
echo "CLI Result: $cli_result"
echo "CLI Status: $cli_status"

echo "Running via HTTP"
echo "URL: $domain/opcache_reset.php"
opcache_reset_http() {
    http_exit_code=0
    http_result=$(ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "curl '$domain/opcache_reset.php' --resolve '$domain:127.0.0.1'")
    http_status=$?
    if [ "$http_result" = 'Failed to reset opcache' ]; then
        echo "FAILED TO RESET OPCACHE. RESET MANUALLY FOR CHANGES TO TAKE EFFECT"
        http_exit_code=1
    elif [ "$http_result" = 'No input file specified.' ]; then
        echo "FAILED TO RESET OPCACHE. RESET MANUALLY FOR CHANGES TO TAKE EFFECT"
        http_exit_code=1
    elif [ $http_status -ne 0 ]; then
        echo "FAILED TO RESET OPCACHE. RESET MANUALLY FOR CHANGES TO TAKE EFFECT"
        http_exit_code=1
    fi
    echo "HTTP Result: $http_result"
    return $http_exit_code
}
# Retry the HTTP request if it fails
http_result=""
http_status=0
for i in $(seq 1 "$attempts_opcache_reset_http"); do
    echo "Attempting HTTP request $i of $attempts_opcache_reset_http"
    copy_opcache_reset_file
    # Capture the result and exit code of the function
    http_result=$(opcache_reset_http)
    # If the function exits with a 0 status code, we're good
    http_status=$?
    remove_opcache_reset_file
    if [ $http_status -eq 0 ]; then
        break
    fi
    echo "Sleeping for $attempts_opcache_reset_http_delay seconds"
    sleep $attempts_opcache_reset_http_delay
done

echo "HTTP Result: $http_result"
echo "HTTP Status: $http_status"

exit_code=0
if [ $cli_status -ne 0 ] && [ $http_status -ne 0 ]; then
    echo "FAILED TO RESET OPCACHE. RESET MANUALLY FOR CHANGES TO TAKE EFFECT"
    exit_code=1
fi

exit $exit_code;
