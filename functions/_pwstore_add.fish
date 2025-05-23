# Internal function to add/update a password in the password store
function _pwstore_add
    # Define paths for password store
    set -l registry_path $pwstore_path/registry.json.gpg

    # Check arguments
    if test (count $argv) -lt 1
        echo "Usage: pw add NAME [--username=VALUE] [--url=VALUE] [DESCRIPTION]"
        echo "       pw gen NAME [LENGTH] [--username=VALUE] [--url=VALUE] [DESCRIPTION]"
        return 1
    end

    # Ensure the directory exists
    mkdir -p $pwstore_path

    # Check if we should generate a password
    set -l generate false
    set -l password_length $pwstore_password_length # Use the global setting
    set -l name ""
    set -l password ""
    set -l username ""
    set -l url ""
    set -l description ""

    # Process arguments
    if test "$argv[1]" = --generate
        set generate true

        if test (count $argv) -lt 2
            echo "Error: Password name is required"
            return 1
        end

        set name $argv[2]
        set remaining_args $argv[3..-1]

        # Check if we have a length parameter (a number)
        if test (count $remaining_args) -ge 1; and string match -qr '^[0-9]+$' -- $remaining_args[1]
            set password_length $remaining_args[1]
            set remaining_args $remaining_args[2..-1]
        end

        # Generate a secure password
        if command -sq openssl
            # Using openssl for better randomness
            set password (openssl rand -base64 (math $password_length \* 3 / 4) | string sub -l $password_length)
        else
            # Fallback to urandom
            set password (head -c 100 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()_+?><~' | head -c $password_length)
        end
    else
        set name $argv[1]
        set remaining_args $argv[2..-1]

        # Check if no-prompt flag is present (used by import scripts)
        set -l no_prompt false
        set -l i 1
        while test $i -le (count $remaining_args)
            set -l arg $remaining_args[$i]
            if test "$arg" = --no-prompt
                set no_prompt true
                # Remove this flag from remaining args
                set -e remaining_args[$i]
                continue
            end
            set i (math $i + 1)
        end

        # Check for password in remaining args (for no-prompt mode)
        if $no_prompt
            if test (count $remaining_args) -ge 1; and not string match -q --regex -- '^--.*=' $remaining_args[1]
                set password $remaining_args[1]
                set remaining_args $remaining_args[2..-1]
            else
                echo "Error: Password required in no-prompt mode"
                return 1
            end
        else
            # Ask for password with masked input
            read -s -P "Enter password for '$name': " password
            echo # Add a newline after the hidden password input

            # Confirm password
            read -s -P "Confirm password: " confirm_password
            echo # Add a newline after the hidden confirmation input

            # Check if passwords match
            if test "$password" != "$confirm_password"
                echo "Error: Passwords do not match"
                return 1
            end
        end
    end

    # Process any remaining arguments for username, url and description
    set -l i 1
    while test $i -le (count $remaining_args)
        set -l arg $remaining_args[$i]

        if string match -q --regex -- '^--username=' $arg
            # Extract username after the equals sign
            set username (string replace -- '--username=' '' $arg)
            # Remove this argument from further processing
            set -e remaining_args[$i]
            continue
        else if string match -q --regex -- '^--url=' $arg
            # Extract URL after the equals sign
            set url (string replace -- '--url=' '' $arg)
            # Remove this argument from further processing 
            set -e remaining_args[$i]
            continue
        end

        set i (math $i + 1)
    end

    # Any remaining arguments become the description
    if test (count $remaining_args) -gt 0
        set description (string join -- " " $remaining_args)
    end

    # If no description provided, use a default one
    if test -z "$description"
        set description "Password for $name"
    end

    # Prepare registry JSON content
    set -l json_content "{}"

    # If we have an existing registry file, decrypt it to memory
    if test -f $registry_path
        set json_content (gpg --quiet --decrypt $registry_path 2>/dev/null)
        if test $status -ne 0
            echo "Failed to decrypt password registry"
            return 1
        end
    end

    # Get the current timestamp
    set -l timestamp (date "+%Y-%m-%d %H:%M:%S")

    # First check if the GPG recipient is valid
    if test -z "$pwstore_gpg_recipient"
        echo "Error: GPG recipient is not set. Please configure pwstore_gpg_recipient."
        echo "Run ./debug_pwstore_gpg.fish for troubleshooting."
        return 1
    end

    # Update the JSON registry with the new password
    set -l json_updated (echo $json_content | jq --arg name "$name" --arg pass "$password" \
       --arg desc "$description" --arg time "$timestamp" --arg user "$username" --arg url "$url" \
       '.[$name] = {"password": $pass, "username": $user, "url": $url, "description": $desc, "updated": $time}')

    # Check if jq succeeded
    if test $status -ne 0
        echo "Failed to update JSON data"
        return 1
    end

    # Try to encrypt and save, capturing any error output
    set -l gpg_output (echo $json_updated | gpg --quiet --yes --recipient "$pwstore_gpg_recipient" --encrypt --output $registry_path 2>&1)
    set -l gpg_status $status

    if test $gpg_status -ne 0
        echo "Failed to encrypt password registry"
        echo "GPG Error: $gpg_output"
        echo "GPG Recipient: $pwstore_gpg_recipient"
        echo "Run ./debug_pwstore_gpg.fish for more detailed troubleshooting."
        return 1
    end

    echo "Password for '$name' has been added/updated successfully"

    # If the password was generated, show it once
    if $generate
        echo "Generated password: $password"
    end
end
