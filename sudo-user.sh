#!/bin/bash

# Prompt for username
read -p "Enter the username for the new sudo user: " username

# Check if username is empty
if [ -z "$username" ]; then
    echo "Username cannot be empty. Exiting."
    exit 1
fi

# Check if user already exists
if id "$username" &>/dev/null; then
    echo "User '$username' already exists. Exiting."
    exit 1
fi

# Create the user with a home directory
echo "Creating user '$username'..."
adduser --quiet --gecos "" "$username"

if [ $? -ne 0 ]; then
    echo "Failed to create user '$username'. Exiting."
    exit 1
fi

# Add the user to the sudo group
echo "Adding '$username' to the sudo group..."
usermod -aG sudo "$username"

if [ $? -ne 0 ]; then
    echo "Failed to add user to sudo group. Exiting."
    exit 1
fi

echo "User '$username' has been created and added to the sudo group."
echo "You will now be switched to the new user. Use 'exit' to return to your original session."

# Switch to the new user
su - "$username"
