#!/bin/bash

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 
    exit 1
fi

# Check if the input file is provided
if [ -z "$1" ]; then
    echo "Usage: bash create_users.sh <name-of-text-file>"
    exit 1
fi

# Log file and secure password storage
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Create necessary directories and set permissions
mkdir -p /var/secure
chmod 700 /var/secure
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE
touch $LOG_FILE

# Log function
log_action() {
    echo "$(date +"%Y-%m-%d %T") - $1" >> $LOG_FILE
}

# Process the input file
while IFS=';' read -r user groups; do
    # Remove leading/trailing whitespace
    user=$(echo "$user" | xargs)
    groups=$(echo "$groups" | xargs)

    # Skip empty lines
    if [ -z "$user" ]; then
        continue
    fi

    # Check if the user already exists
    if id "$user" &>/dev/null; then
        log_action "User $user already exists"
        continue
    fi

    # Create the user's personal group
    if ! getent group "$user" &>/dev/null; then
        groupadd "$user"
        log_action "Personal group $user created"
    fi

    # Create the user and add to their personal group
    useradd -m -s /bin/bash -g "$user" "$user"
    if [ $? -eq 0 ]; then
        log_action "User $user created and added to personal group $user"
    else
        log_action "Failed to create user $user"
        continue
    fi

    # Generate a random password
    password=$(openssl rand -base64 12)
    echo "$user:$password" | chpasswd
    if [ $? -eq 0 ]; then
        log_action "Password set for user $user"
    else
        log_action "Failed to set password for user $user"
    fi

    # Add the user to specified groups
    IFS=',' read -r -a group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)
        # Check if the group exists, create if it does not
        if [ -n "$group" ]; then
            if ! getent group "$group" &>/dev/null; then
                groupadd "$group"
                if [ $? -eq 0 ]; then
                    log_action "Group $group created"
                else
                    log_action "Failed to create group $group"
                fi
            fi
            usermod -aG "$group" "$user"
            if [ $? -eq 0 ]; then
                log_action "User $user added to group $group"
            else
                log_action "Failed to add user $user to group $group"
            fi
        fi
    done

    # Securely store the password
    echo "$user,$password" >> $PASSWORD_FILE

done < "$1"

echo "User creation process completed. Check $LOG_FILE for details."

