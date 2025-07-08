#!/usr/bin/env sh

. /functions.sh

domain=$1
webroot_path=$2
if [ -z $3 ]; then
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
max_attempts_opcache_reset_http=${11}
max_attempts_opcache_reset_cli=${12}
delay_attempts_opcache_reset_http=${13}
delay_attempts_opcache_reset_cli=${14}
secret=${15}
curl_protocol=${16}
curl_port=${17}

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
echo "Attempts Opcache Reset HTTP: $max_attempts_opcache_reset_http"
echo "Attempts Opcache Reset CLI: $max_attempts_opcache_reset_cli"
echo "Attempts Opcache Reset HTTP Delay: $delay_attempts_opcache_reset_http"
echo "Attempts Opcache Reset CLI Delay: $delay_attempts_opcache_reset_cli"
echo "Curl Protocol: $curl_protocol"
echo "Curl Port: $curl_port"

echo "Preparing SSH..."
echo "$ssh_key" >repo_private_key
echo "Setting key permissions"
#set permissions on private keys to avoid unprotected private key file error
chmod 600 repo_private_key
echo "Running ssh-keyscan and writing to known_hosts"
#run ssh-keyscan to add host to known_hosts
ssh-keyscan -p $ssh_port -H $ssh_host >/etc/ssh/ssh_known_hosts
echo "Preparing SSH agent forwards..."
eval $(ssh-agent -s)
echo "Adding key to SSH"
ssh-add repo_private_key
echo "SSH prepared!"

echo "Checking if PHP file preexists on remote server"
php_file_preexists=$(ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "test -f $webroot_path/opcache_reset.php && echo 'true' || echo 'false'")
if [ "$php_file_preexists" = 'true' ]; then
    echo "opcache_reset.php already exists on $ssh_host"
else
    echo "opcache_reset.php does not exist on $ssh_host"
    echo "Creating the local PHP file"
    echo "<?php if ( function_exists( 'opcache_reset' ) ) { echo opcache_reset() ? 'Opcache Reset!' : 'Failed to reset opcache'; } else { echo 'Not using opcache'; }" >opcache_reset.php
fi

# Retry the CLI request if it fails
echo "Running via CLI, just in case in use"
cli_result=""
cli_status=0
for i in $(seq 1 "$max_attempts_opcache_reset_cli"); do
    echo "Attempting CLI request $i of $max_attempts_opcache_reset_cli"
    copy_opcache_reset_file_if_not_preexists
    # Capture the result and exit code of the function
    cli_result=$(opcache_reset_cli)
    # If the function exits with a 0 status code, we're good
    cli_status=$?
    echo "CLI Result: $cli_result"
    echo "CLI Status: $cli_status"
    remove_opcache_reset_file_if_not_preexists
    if [ $cli_status -eq 0 ]; then
        break
    fi
    echo "Sleeping for $delay_attempts_opcache_reset_cli seconds"
    sleep $delay_attempts_opcache_reset_cli
done

# We haven't encountered a situation where the CLI using opcache was an issue, so if it fails, it's *probably* not the end of the world and not worth failing the job
echo "CLI Result: $cli_result"
echo "CLI Status: $cli_status"

echo "Running via HTTP"
echo "URL: $domain/opcache_reset.php"
# Retry the HTTP request if it fails
http_result=""
http_status=0
for i in $(seq 1 "$max_attempts_opcache_reset_http"); do
    echo "Attempting HTTP request $i of $max_attempts_opcache_reset_http"
    copy_opcache_reset_file_if_not_preexists
    # Capture the result and exit code of the function
    http_result=$(opcache_reset_http)
    # If the function exits with a 0 status code, we're good
    http_status=$?
    echo "HTTP Result: $http_result"
    echo "HTTP Status: $http_status"
    remove_opcache_reset_file_if_not_preexists
    if [ $http_status -eq 0 ]; then
        break
    fi
    echo "Sleeping for $delay_attempts_opcache_reset_http seconds"
    sleep $delay_attempts_opcache_reset_http
done

echo "HTTP Result: $http_result"
echo "HTTP Status: $http_status"

exit_code=0
if [ $cli_status -ne 0 ] && [ $http_status -ne 0 ]; then
    echo "FAILED TO RESET OPCACHE. RESET MANUALLY FOR CHANGES TO TAKE EFFECT"
    exit_code=1
fi

exit $exit_code
