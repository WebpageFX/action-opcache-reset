#!/usr/bin/env sh

copy_opcache_reset_file() {
    echo "Copying opcache_reset.php to $ssh_host"
    scp -o ForwardAgent=yes -P $ssh_port -i repo_private_key ./opcache_reset.php $ssh_user@$ssh_host:$webroot_path/opcache_reset.php

    if [ -z "$owner" ]; then
        echo "User provided, running chown to $owner"
        ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "chown $owner $webroot_path/opcache_reset.php"
    else
        echo "Relying on default user"
    fi

    if [ -z "$group" ]; then
        echo "Group provided, running chgrp to $group"
        ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "chgrp $group $webroot_path/opcache_reset.php"
    else
        echo "Relying on default group"
    fi

    echo "Setting permissions"
    ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "chmod $octal_permissions $webroot_path/opcache_reset.php"
}

copy_opcache_reset_file_if_not_preexists() {
    if [ "$php_file_preexists" = 'false' ]; then
        copy_opcache_reset_file
    else
        echo "opcache_reset.php already exists on $ssh_host"
    fi
}

remove_opcache_reset_file() {
    echo "Removing opcache_reset.php from $ssh_host"
    ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "rm $webroot_path/opcache_reset.php"
}

remove_opcache_reset_file_if_not_preexists() {
    if [ "$php_file_preexists" = 'false' ]; then
        remove_opcache_reset_file
    else
        echo "opcache_reset.php already exists on $ssh_host"
    fi
}

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

opcache_reset_http() {
    http_exit_code=0
    if [ $secret ]; then
        http_result=$(ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "curl '$curl_protocol://$domain/opcache_reset.php?fx_reset=$secret' --resolve '$domain:$curl_port:127.0.0.1'")
    else
        http_result=$(ssh -p $ssh_port -i repo_private_key $ssh_user@$ssh_host "curl '$curl_protocol://$domain/opcache_reset.php' --resolve '$domain:$curl_port:127.0.0.1'")
    fi
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
