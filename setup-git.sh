#!/usr/bin/env bash
if [ -z "$test_setup" ]; then
    set -e
    set -u

    tmp_log_file=$(mktemp)
    teetmp() { tee -a "$tmp_log_file" /dev/tty; }

    readeable_log_file_before() {
        echo "" | teetmp
        echo "" | teetmp
        echo "---------------------------------------------------------------" | teetmp
    }

    readeable_log_file_after() {
        echo "---------------------------------------------------------------" | teetmp
        echo "" | teetmp
        echo "" | teetmp
    }

    log_and_run() {
        cmd="$1"
        readeable_log_file_before
        echo "Executing: $cmd" | teetmp
        readeable_log_file_after

        set +e
        eval "$cmd" 2>&1 | teetmp
        cmd_exit_status=$?
        set -e

        if [ $cmd_exit_status -ne 0 ]; then
            echo "Command failed with exit status $cmd_exit_status: $cmd" | teetmp
            mv "$tmp_log_file" ./setup_git.log

            echo "cat ./setup_git.log"
            echo "nvim ./setup_git.log"

            exit 1
        fi
    }

    readeable_log_file_before
    echo "$(date) Starting the Setup for Git & GitHub CLI..." | teetmp
    readeable_log_file_after

    readeable_log_file_before
    echo "Created a log file in the same directory of this script location" | teetmp
    readeable_log_file_after
    USERNAME="${USERNAME:-}"
    EMAIL="${EMAIL:-}"
    # Prompt user for name and email only if they are not provided
    if [ -z "$USERNAME" ]; then
        readeable_log_file_before
        read -rp "Enter your username: "  USERNAME && log_and_run "echo 'Name acquired'"
        readeable_log_file_after
    fi
    if [ -z "$EMAIL" ]; then
        readeable_log_file_before
        read -rp "Enter your email: "  EMAIL && log_and_run "echo 'Email acquired'"
        readeable_log_file_after
    fi

    # Set the provided name and email for git
    readeable_log_file_before
    git config --global user.name "$USERNAME" && log_and_run "echo 'Set the git global username'"
    readeable_log_file_after

    readeable_log_file_before
    git config --global user.email "$EMAIL" && log_and_run "echo 'Set the git global email'"
    readeable_log_file_after

    # Generate SSH key
    ssh_key_path="$HOME/.ssh/id_ed25519"
    if [ ! -f "$ssh_key_path" ]; then
        readeable_log_file_before
        ssh-keygen -t ed25519 -C "$EMAIL"  && log_and_run "echo 'Set the git global email'"
        readeable_log_file_after
        # Start the ssh-agent and load the SSH key
        readeable_log_file_before
        eval "$(ssh-agent -s)" && log_and_run "echo 'Started the ssh-agent'"
        readeable_log_file_after

        readeable_log_file_before
        ssh-add "$ssh_key_path" && log_and_run "echo 'Added the SSH Key'"
        readeable_log_file_after
    fi


    # Authenticate GitHub CLI
    if command -v gh > /dev/null 2>&1; then
        readeable_log_file_before
        echo "GitHub Cli is installed" | teetmp
        readeable_log_file_after

        readeable_log_file_before
        gh auth login -s 'user:email,read:org,repo,write:org,notifications' -p ssh && log_and_run "echo 'Logged in to GitHub'"
        readeable_log_file_after
    else
        readeable_log_file_before
        echo "See the Linux/BSD page for distro speciffic instuctions"      | teetmp
        echo "https://github.com/cli/cli/blob/trunk/docs/install_linux.md"  | teetmp
        echo "GitHub Cli is not installed" | teetmp
        readeable_log_file_after
        exit 1
    fi

    # Test the SSH connection to GitHub
    readeable_log_file_before
    log_and_run "ssh -T git@github.com"
    readeable_log_file_after

    readeable_log_file_before
    echo "Git and SSH have been configured with the provided name and email."
    readeable_log_file_after
    exit 0
else
    USERNAME=$(if test -z "${username-}"; then read -rp "Provide your username: " username; fi)
    EMAIL=$(if test -z "${email-}"; then read -rp "Provide your email: " email; fi)
    git config --global user.name "$USERNAME"
    git config --global user.email "$EMAIL"
    ssh_key_path="$HOME/.ssh/id_ed25519"
    if [ ! -f "$ssh_key_path" ]; then
        ssh-keygen -t ed25519 -C "$EMAIL"  && echo 'Set the git global email'
        # Start the ssh-agent and load the SSH key
        eval "$(ssh-agent -s)" && echo 'Started the ssh-agent'
        ssh-add "$ssh_key_path" && echo 'Added the SSH Key'
    fi
    if command -v gh > /dev/null 2>&1; then
        logged_in=$(if test -z "$logged_in"; then if test "$(gh auth status | grep -c "Logged in to github.com")" -ne 0; then echo "true"; else echo "false"; fi; fi)
        if [ "$logged_in" = "false" ]; then
            gh auth login -s 'user:email,read:org,repo,write:org,notifications' -p ssh
        fi
        test_ssh=$(ssh -T git@github.com)
        if [ "$(echo "$test_ssh" 2>&1 | grep -c "successfully authenticated")" -ne 0 ]; then
            echo "Git and SSH have been configured with the provided name and email."
        else
            echo "Git and SSH have been configured with the provided name and email."
            echo "But the SSH connection to GitHub failed."
            echo "Please check the SSH key and try again."
        fi
    fi
fi
