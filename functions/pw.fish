# Main interface for the password store
function pw
    if test (count $argv) -eq 0
        # No arguments, show help
        echo "Password Store"
        echo "Usage: pw COMMAND [ARGS...]"
        echo ""
        echo "Available commands:"
        echo "  add NAME [--username=VALUE] [--url=VALUE] [DESC] - Add or update a password (will prompt for password)"
        echo "  gen NAME [LENGTH] [--username=VALUE] [--url=VALUE] [DESC] - Generate and store a password"
        echo "  get NAME                    - Copy password to clipboard"
        echo "  show NAME                   - Show password in terminal"
        echo "  user NAME                   - Copy username to clipboard"
        echo "  url NAME                    - Copy URL to clipboard"
        echo "  desc NAME                   - Copy description to clipboard"
        echo "  ls, list                    - List all passwords"
        echo "  rm NAME                     - Delete a password"
        echo "  export PATH                 - Export passwords to a file"
        echo "  import PATH                 - Import passwords from a file"
        echo "  import-pass [DIR] [--verbose] [--no-confirm] - Import passwords from standard pass"
        # Remove the obsolete import-pass-verbose command
        echo "  migrate                     - Migrate passwords from old location"
        echo "  version, --version, -v      - Show pwstore version"
        echo "  help                        - Show this help message"
        return 0
    end

    # Parse the command
    set -l command $argv[1]
    set -l args $argv[2..-1]

    switch $command
        case help
            pw

        case --version -v
            echo "fish-pwstore v1.5.3"

        case add
            if test (count $args) -lt 1
                echo "Usage: pw add NAME [--username=VALUE] [--url=VALUE] [DESCRIPTION]"
                return 1
            end
            _pwstore_add $args

        case gen generate
            if test (count $args) -lt 1
                echo "Usage: pw gen NAME [LENGTH] [--username=VALUE] [--url=VALUE] [DESCRIPTION]"
                return 1
            end
            _pwstore_add --generate $args

        case get
            if test (count $args) -lt 1
                echo "Usage: pw get NAME"
                return 1
            end
            _pwstore_get $args[1] --copy

        case show
            if test (count $args) -lt 1
                echo "Usage: pw show NAME"
                return 1
            end
            _pwstore_get $args[1] --show

        case user username email
            if test (count $args) -lt 1
                echo "Usage: pw user NAME"
                return 1
            end
            _pwstore_get $args[1] --username

        case url link website
            if test (count $args) -lt 1
                echo "Usage: pw url NAME"
                return 1
            end
            _pwstore_get $args[1] --url

        case desc description
            if test (count $args) -lt 1
                echo "Usage: pw desc NAME"
                return 1
            end
            _pwstore_get $args[1] --description

        case ls list
            _pwstore_list $args

        case rm delete remove
            if test (count $args) -lt 1
                echo "Usage: pw rm NAME [--force]"
                return 1
            end
            _pwstore_delete $args

        case export
            if test (count $args) -lt 1
                echo "Usage: pw export PATH"
                return 1
            end
            _pwstore_export $args

        case import
            if test (count $args) -lt 1
                echo "Usage: pw import PATH [--merge|--overwrite]"
                return 1
            end
            _pwstore_import $args

        case init
            _pwstore_init

        case migrate
            _pwstore_migrate

        case version
            echo "fish-pwstore v1.5.3"

        case import-pass
            # Process flags that need special handling
            set -l verbose_flag false
            set -l no_confirm_flag false
            set -l filtered_args

            for arg in $args
                if test "$arg" = --verbose
                    set verbose_flag true
                else if test "$arg" = --no-confirm
                    set no_confirm_flag true
                else
                    set filtered_args $filtered_args $arg
                end
            end

            # Build the command with the appropriate flags
            set -l cmd_args $filtered_args
            test "$verbose_flag" = true; and set cmd_args $cmd_args --verbose
            test "$no_confirm_flag" = true; and set cmd_args $cmd_args --no-confirm

            # Pass all arguments to the internal function
            _pwstore_import_from_pass $cmd_args

        case "*"
            echo "Unknown command: $command"
            echo "Run 'pw help' to see available commands"
            return 1
    end
end

# Consolidated utility functions for the password store
# This file contains all the helper functions used by the pwstore

# =============================================================================
# PATH UTILITIES
# =============================================================================

# Function to get absolute path of a file or directory
# Works across platforms with fallbacks for systems without realpath/grealpath
function _pwstore_resolve_path --description "Get absolute path with robust fallback methods"
    set -l path_to_resolve $argv[1]

    if test -z "$path_to_resolve"
        return 1
    end

    # Method 1: Use built-in realpath if available
    if command -sq realpath
        realpath "$path_to_resolve" 2>/dev/null
        and return 0
    end

    # Method 2: Use grealpath (GNU coreutils on macOS) if available
    if command -sq grealpath
        command grealpath "$path_to_resolve" 2>/dev/null
        and return 0
    end

    # Method 3: Use Python's os.path.abspath if available
    if type -q python3
        python3 -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null
        and return 0
    end

    # Method 4: Use Python 2 if Python 3 isn't available
    if type -q python
        python -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null
        and return 0
    end

    # Method 5: Try readlink -f (works on some systems)
    if command -sq readlink
        readlink -f "$path_to_resolve" 2>/dev/null
        and return 0
    end

    # Method 6: For directories, use pwd
    if test -d "$path_to_resolve"
        pushd "$path_to_resolve" >/dev/null
        pwd
        popd >/dev/null
        and return 0
    end

    # Method 7: For files, get the absolute path of the directory, then append the filename
    if test -f "$path_to_resolve"
        set -l dir_name (dirname "$path_to_resolve")
        set -l base_name (basename "$path_to_resolve")
        pushd "$dir_name" >/dev/null
        echo (pwd)/"$base_name"
        popd >/dev/null
        and return 0
    end

    # Method 8: Last resort, return the path unchanged
    echo "$path_to_resolve"
    return 0
end

# Function to extract a relative path from a base directory
function _pwstore_get_relative_path --description "Get path relative to a base directory"
    set -l base_dir $argv[1]
    set -l target_path $argv[2]

    if test -z "$base_dir"; or test -z "$target_path"
        return 1
    end

    # Get absolute paths first
    set -l abs_base_dir (_pwstore_resolve_path "$base_dir")
    set -l abs_target_path (_pwstore_resolve_path "$target_path")

    # Escape special characters in the directory path for regex
    set -l escaped_dir (string escape --style=regex "$abs_base_dir")

    # Extract relative path using regex replacement
    string replace -r "^$escaped_dir/" "" "$abs_target_path"
    return $status
end

# =============================================================================
# ADD/UPDATE PASSWORD
# =============================================================================

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
                set -e remaining_args[1]
            else
                echo "Error: Password is required when using --no-prompt"
                return 1
            end
        else
            # Prompt for password
            read -s -P "Enter password for $name: " password
            echo ""
            read -s -P "Confirm password: " confirm
            echo ""

            if test "$password" != "$confirm"
                echo "Passwords don't match"
                return 1
            end
        end
    end

    # Process any remaining arguments for username, url and description
    set -l i 1
    while test $i -le (count $remaining_args)
        set -l arg $remaining_args[$i]

        # Check for --username=VALUE format
        if string match -qr '^--username=' -- "$arg"
            set username (string replace --regex '^--username=' '' -- "$arg")
            set -e remaining_args[$i]
            continue
        end

        # Check for --url=VALUE format
        if string match -qr '^--url=' -- "$arg"
            set url (string replace --regex '^--url=' '' -- "$arg")
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
            echo "Failed to decrypt the password registry"
            return 1
        end
    end

    # Get the current timestamp
    set -l timestamp (date "+%Y-%m-%d %H:%M:%S")

    # First check if the GPG recipient is valid
    if test -z "$pwstore_gpg_recipient"
        echo "Error: GPG recipient is not set. Please configure pwstore_gpg_recipient."
        return 1
    end

    # Update the JSON registry with the new password
    set -l json_updated (echo $json_content | jq --arg name "$name" --arg pass "$password" \
        --arg user "$username" --arg url "$url" --arg desc "$description" --arg time "$timestamp" \
        '.[$name] = {"password": $pass, "username": $user, "url": $url, "description": $desc, "modified": $time}')

    # Check if jq succeeded
    if test $status -ne 0
        echo "Failed to update the password registry JSON"
        return 1
    end

    # Try to encrypt and save, capturing any error output
    set -l gpg_output (echo $json_updated | gpg --quiet --yes --recipient "$pwstore_gpg_recipient" --encrypt --output $registry_path 2>&1)
    set -l gpg_status $status

    if test $gpg_status -ne 0
        echo "Failed to encrypt and save the password registry"
        echo "GPG Error: $gpg_output"
        return 1
    end

    echo "Password for '$name' has been added/updated successfully"

    # If the password was generated, show it once
    if $generate
        echo "Generated password: $password"
    end
end

# =============================================================================
# DELETE PASSWORD
# =============================================================================

# Internal function to delete a password from the password store
function _pwstore_delete
    # Define paths for password store
    set -l registry_path $pwstore_path/registry.json.gpg

    # Check arguments
    if test (count $argv) -lt 1
        echo "Usage: pw rm NAME [--force]"
        return 1
    end

    set -l name $argv[1]
    set -l force false

    for arg in $argv[2..-1]
        if test "$arg" = --force
            set force true
        end
    end

    # Check if registry exists
    if test ! -f $registry_path
        echo "No password registry found."
        return 1
    end

    # Decrypt the registry directly to memory
    set -l decrypted_content (gpg --quiet --decrypt $registry_path 2>/dev/null)
    if test $status -ne 0
        echo "Failed to decrypt password registry"
        return 1
    end

    # Check if the password exists
    if not echo $decrypted_content | jq -e --arg name "$name" 'has($name)' >/dev/null
        echo "Password for '$name' not found"
        return 1
    end

    # Get description for confirmation
    set -l description (echo $decrypted_content | jq -r --arg name "$name" '.[$name].description')

    # Confirm deletion unless --force is used
    if not $force
        read -l -P "Delete password for '$name' ($description)? [y/N] " confirm
        if not string match -qi y $confirm
            echo "Operation cancelled."
            return 0
        end
    end

    # Remove the entry from the registry
    echo $decrypted_content | jq --arg name "$name" 'del(.[$name])' | gpg --quiet --yes --recipient "$pwstore_gpg_recipient" --encrypt --output $registry_path

    if test $status -ne 0
        echo "Failed to update password registry"
        return 1
    end

    echo "Password for '$name' deleted successfully"
end

# =============================================================================
# EXPORT PASSWORDS
# =============================================================================

# Internal function to export passwords to a GPG-encrypted backup file
function _pwstore_export
    # Define paths for password store
    set -l registry_path $pwstore_path/registry.json.gpg

    # Check arguments
    if test (count $argv) -lt 1
        echo "Usage: pw export EXPORT_PATH"
        return 1
    end

    set -l export_path $argv[1]

    # Check if registry exists
    if test ! -f $registry_path
        echo "No password registry found."
        return 1
    end

    # Check if export path has .gpg extension
    if not string match -q "*.gpg" -- "$export_path"
        set export_path "$export_path.gpg"
    end

    # Decrypt and re-encrypt to the export path
    if gpg --decrypt $registry_path 2>/dev/null | gpg --recipient "$pwstore_gpg_recipient" --encrypt --output $export_path
        echo "Passwords exported to $export_path"
    else
        echo "Failed to export passwords."
        return 1
    end

    return 0
end

# =============================================================================
# GET PASSWORD
# =============================================================================

# Internal function to retrieve a password from the password store
function _pwstore_get
    # Define paths for password store
    set -l registry_path $pwstore_path/registry.json.gpg

    # Check arguments
    if test (count $argv) -lt 1
        echo "Usage: pw get NAME [--copy] [--show]"
        echo "       Use --copy to copy to clipboard (default)"
        echo "       Use --show to print the password to the terminal"
        return 1
    end

    # Parse arguments
    set -l name $argv[1]
    set -l copy_to_clipboard true
    set -l show_password false
    set -l get_username false
    set -l get_url false
    set -l get_description false
    set -l get_field false
    set -l field_name ""

    for arg in $argv[2..-1]
        switch $arg
            case --copy -c
                set copy_to_clipboard true
                set show_password false
            case --show -s
                set show_password true
                set copy_to_clipboard false
            case --no-copy
                set copy_to_clipboard false
            case --username -u
                set get_username true
                set get_url false
                set get_description false
                set get_field false
            case --url --link -l
                set get_url true
                set get_username false
                set get_description false
                set get_field false
            case --description -d
                set get_description true
                set get_username false
                set get_url false
                set get_field false
            case -f --field
                set get_field true
                set get_username false
                set get_url false
                set get_description false
                if test (count $argv) -gt 3
                    set field_name $argv[3]
                end
        end
    end

    # Check if registry exists
    if test ! -f $registry_path
        echo "No password registry found. Initialize with 'pw init' first."
        return 1
    end

    # Get the registry contents
    set -l registry_content (gpg --decrypt $registry_path 2>/dev/null)
    if test $status -ne 0
        echo "Failed to decrypt the password registry."
        return 1
    end

    # Parse the JSON and find the password
    set -l json (echo $registry_content | string join '\n')
    set -l password_data (echo $json | jq -r ".\"$name\"")

    if test "$password_data" = null
        echo "Password '$name' not found."
        return 1
    end

    # Extract the value based on what was requested
    if $get_username
        set -l username (echo $password_data | jq -r '.username')
        if test "$username" = null -o "$username" = ""
            echo "No username stored for '$name'."
            return 1
        end

        if $copy_to_clipboard
            echo $username | fish_clipboard_copy
            echo "Username for '$name' copied to clipboard."
        else
            echo $username
        end

        return 0
    end

    if $get_url
        set -l url (echo $password_data | jq -r '.url')
        if test "$url" = null -o "$url" = ""
            echo "No URL stored for '$name'."
            return 1
        end

        if $copy_to_clipboard
            echo $url | fish_clipboard_copy
            echo "URL for '$name' copied to clipboard."
        else
            echo $url
        end

        return 0
    end

    if $get_description
        set -l description (echo $password_data | jq -r '.description')
        if test "$description" = null -o "$description" = ""
            echo "No description stored for '$name'."
            return 1
        end

        if $copy_to_clipboard
            echo $description | fish_clipboard_copy
            echo "Description for '$name' copied to clipboard."
        else
            echo $description
        end

        return 0
    end

    if $get_field
        # Allow field access to any of the standard fields
        switch $field_name
            case password pass pwd
                set -l password (echo $password_data | jq -r '.password')
                if test "$password" = null -o "$password" = ""
                    echo "No password stored for '$name'."
                    return 1
                end

                if $copy_to_clipboard
                    echo $password | fish_clipboard_copy
                    echo "Password for '$name' copied to clipboard."
                else
                    echo $password
                end
                return 0

            case username user login email
                set -l username (echo $password_data | jq -r '.username')
                if test "$username" = null -o "$username" = ""
                    echo "No username stored for '$name'."
                    return 1
                end

                if $copy_to_clipboard
                    echo $username | fish_clipboard_copy
                    echo "Username for '$name' copied to clipboard."
                else
                    echo $username
                end
                return 0

            case url website link site
                set -l url (echo $password_data | jq -r '.url')
                if test "$url" = null -o "$url" = ""
                    echo "No URL stored for '$name'."
                    return 1
                end

                if $copy_to_clipboard
                    echo $url | fish_clipboard_copy
                    echo "URL for '$name' copied to clipboard."
                else
                    echo $url
                end
                return 0

            case description desc note notes
                set -l description (echo $password_data | jq -r '.description')
                if test "$description" = null -o "$description" = ""
                    echo "No description stored for '$name'."
                    return 1
                end

                if $copy_to_clipboard
                    echo $description | fish_clipboard_copy
                    echo "Description for '$name' copied to clipboard."
                else
                    echo $description
                end
                return 0

            case '*'
                # Try to find the field in the password data (using jq)
                echo "Field '$field_name' not found in password data."
                return 1
        end
    end

    # Get the password and metadata
    set -l password (echo $password_data | jq -r '.password')
    set -l username (echo $password_data | jq -r '.username')
    set -l url (echo $password_data | jq -r '.url')
    set -l description (echo $password_data | jq -r '.description')

    if $copy_to_clipboard
        echo $password | fish_clipboard_copy
        echo "Password for '$name' copied to clipboard."
    end

    if $show_password
        # Show password along with other details if available
        echo "Password for '$name':"
        echo "Password: $password"

        # Show username if available
        if test "$username" != null -a "$username" != ""
            echo "Username: $username"
        end

        # Show URL if available
        if test "$url" != null -a "$url" != ""
            echo "URL: $url"
        end

        # Show description if available
        if test "$description" != null -a "$description" != ""
            echo "Description: $description"
        end
    end

    return 0
end

# =============================================================================
# IMPORT PASSWORDS
# =============================================================================

# Internal function to import passwords from a GPG-encrypted backup file
function _pwstore_import
    # Define paths for password store
    set -l registry_path $pwstore_path/registry.json.gpg

    # Check arguments
    if test (count $argv) -lt 1
        echo "Usage: pw import IMPORT_PATH [--merge] [--overwrite]"
        echo "       Use --merge to combine with existing passwords (default)"
        echo "       Use --overwrite to replace all existing passwords"
        return 1
    end

    set -l import_path $argv[1]
    set -l merge true

    for arg in $argv[2..-1]
        switch $arg
            case --merge
                set merge true
            case --overwrite
                set merge false
        end
    end

    # Check if import file exists
    if test ! -f $import_path
        echo "Import file not found: $import_path"
        return 1
    end

    # Check if registry already exists
    set -l existing_data "{}"
    if test -f $registry_path
        if $merge
            set existing_data (gpg --decrypt $registry_path 2>/dev/null)
            if test $status -ne 0
                echo "Failed to decrypt the existing password registry."
                return 1
            end
        end
    end

    # Decrypt the import file
    set -l import_data (gpg --decrypt $import_path 2>/dev/null)
    if test $status -ne 0
        echo "Failed to decrypt the import file."
        return 1
    end

    # Merge or replace data
    if $merge -a "$existing_data" != "{}"
        # Combine the JSONs
        set -l merged_data (echo "$existing_data" | jq -s '.[0] * .[1]' - <(echo "$import_data") 2>/dev/null)
        if test $status -ne 0
            echo "Failed to merge password data."
            return 1
        end
        set import_data $merged_data
    end

    # Ensure the directory exists
    mkdir -p $pwstore_path

    # Encrypt and save the merged data
    # First check if the GPG recipient is valid
    if test -z "$pwstore_gpg_recipient"
        echo "Error: GPG recipient is not set. Please configure pwstore_gpg_recipient."
        echo "Run ./debug_pwstore_gpg.fish for troubleshooting."
        return 1
    end

    # Check that the directory is writable
    if not test -w (dirname $registry_path)
        echo "Error: Cannot write to directory: "(dirname $registry_path)
        echo "Run ./debug_pwstore_gpg.fish for troubleshooting."
        return 1
    end

    # Try to encrypt and save, but capture the error output for debugging
    set -l gpg_output (echo $import_data | gpg --recipient "$pwstore_gpg_recipient" --encrypt --output $registry_path 2>&1)
    set -l gpg_status $status

    if test $gpg_status -ne 0
        echo "Failed to encrypt and save the imported passwords."
        echo "GPG Error: $gpg_output"
        echo "GPG Recipient: $pwstore_gpg_recipient"
        echo "Run ./debug_pwstore_gpg.fish for more detailed troubleshooting."
        return 1
    end

    echo "Passwords imported successfully."
    return 0
end

# =============================================================================
# IMPORT FROM PASS
# =============================================================================

# Internal function to import passwords from the standard pass password manager utility
function _pwstore_import_from_pass
    # Check if PASSWORD_STORE_DIR is set, otherwise use default
    set -l pass_dir
    if set -q PASSWORD_STORE_DIR
        set pass_dir $PASSWORD_STORE_DIR
    else
        set pass_dir $HOME/.password-store
    end
    set -l verbose false
    set -l no_confirm false

    # Parse arguments
    set -l args_to_process $argv
    set -l i 1
    while test $i -le (count $args_to_process)
        set -l arg $args_to_process[$i]

        if test "$arg" = --verbose
            set verbose true
            set -e args_to_process[$i]
        else if test "$arg" = --no-confirm
            set no_confirm true
            set -e args_to_process[$i]
        else if test -d "$arg"
            set pass_dir "$arg"
            set -e args_to_process[$i]
        else
            set i (math $i + 1)
        end
    end

    # Check if pass directory exists
    if not test -d $pass_dir
        echo "Pass directory not found: $pass_dir"
        echo "Usage: pw import-pass [PASS_DIRECTORY] [--verbose]"

        # Diagnostic information
        echo ""
        echo "Diagnostic information:"
        echo "Current PASSWORD_STORE_DIR environment variable: $PASSWORD_STORE_DIR"
        echo "Default pass directory would be: $HOME/.password-store"
        echo ""
        echo "Try one of these commands:"
        echo "  pw import-pass $HOME/.password-store"
        echo "  env PASSWORD_STORE_DIR=/path/to/password/store pw import-pass"
        return 1
    end

    # Count the number of password files
    set -l password_files (find $pass_dir -name "*.gpg" | wc -l)

    if test $password_files -eq 0
        echo "No password files (*.gpg) found in $pass_dir"
        echo "Make sure this is a valid pass password store."
        return 1
    end

    echo "Found $password_files password files in $pass_dir"
    if test "$verbose" = true
        echo "Pass directory structure:"
        find $pass_dir -name "*.gpg" -not -path "*/\.*" | sort
    end

    # Skip confirmation if --no-confirm was specified or if we're in CI environment
    if test "$no_confirm" = true; or test "$CI" = true
        if test "$verbose" = true
            echo "Skipping confirmation prompt (--no-confirm or CI=true)"
        end
    else
        read -l -P "Proceed with import? [y/N] " confirm

        if not string match -qi y $confirm
            echo "Import cancelled."
            return 0
        end
    end

    # Initialize counter
    set -l imported 0
    set -l failed 0

    # Find all .gpg files
    set -l total_files (find $pass_dir -name "*.gpg" | wc -l | string trim)
    set -l current_file_num 0

    for file in (find $pass_dir -name "*.gpg")
        set current_file_num (math $current_file_num + 1)

        echo "════════════════════════════════════════════════════════════════════════════"
        echo "IMPORT [$current_file_num/$total_files]: STARTING"
        echo "════════════════════════════════════════════════════════════════════════════"

        # Get absolute paths for both the pass directory and the file using our utility function
        set -l real_pass_dir (_pwstore_resolve_path "$pass_dir")
        set -l real_file (_pwstore_resolve_path "$file")

        if test "$verbose" = true
            echo "  Debug: Resolved pass directory path: $real_pass_dir"
            echo "  Debug: Resolved file path: $real_file"
        end

        # Extract the relative path from the pass directory
        # Escape special characters in the directory path for regex
        set -l escaped_dir (string escape --style=regex "$real_pass_dir")
        set -l rel_path (string replace -r "^$escaped_dir/" "" "$real_file")

        # Remove the .gpg extension for our password store name
        set -l name (string replace -r "\.gpg\$" "" $rel_path)

        # Keep the original hierarchy with slashes
        # No need to replace slashes with dots

        echo "Importing [$current_file_num/$total_files]: $name"

        # For 'pass show', we need the path relative to the pass directory without .gpg extension
        set -l pass_name (string replace -r "\.gpg\$" "" $rel_path)

        if test "$verbose" = true
            echo "  Debug: File absolute path: $real_file"
            echo "  Debug: Pass dir absolute path: $real_pass_dir"
            echo "  Debug: Calculated relative path: $rel_path"
        end

        if test "$verbose" = true
            echo "  Debug: Using 'pass show $pass_name'"
        end

        # Attempt to decrypt the pass file
        # Use the specific pass directory when calling pass
        # The output is automatically split into lines in Fish
        set -l password_data

        # We don't need to handle ./ paths anymore since we're using realpath
        # The following check is retained for compatibility but should no longer be needed
        if string match -q "./*" -- "$pass_name"
            set pass_name (string replace -r "^\./" "" $pass_name)
            if test "$verbose" = true
                echo "  Debug: Removed leading ./ from path: 'pass show $pass_name'"
            end
        end

        # Try to decrypt the password using pass
        set -x PASSWORD_STORE_DIR $pass_dir
        set password_data (pass show $pass_name 2>/dev/null)
        echo "  Debug: pass show output: $password_data"

        # First line is the password
        set -l password_line $password_data[1]

        # Look for metadata in subsequent lines
        set -l username ""
        set -l url ""
        set -l additional_description ""

        # Check from the second line onwards for metadata patterns
        for i in (seq 2 (count $password_data))
            set -l line $password_data[$i]

            # Look for username formatted lines
            if string match -q -r -i '^(username|user|login|email):' -- "$line"
                set username (string replace -r '^[^:]+:\s*' '' -- "$line")
                # Look for URL lines
            else if string match -q -r -i '^(url|website|site|link):' -- "$line"
                set url (string replace -r '^[^:]+:\s*' '' -- "$line")
                # Look for description lines
            else if string match -q -r -i '^(description|desc|notes|note):' -- "$line"
                set additional_description (string replace -r '^[^:]+:\s*' '' -- "$line")
            end
        end

        # Clean up any trailing control characters
        set password_line (string trim -- "$password_line")

        if test -n "$username"
            set username (string trim -- "$username")
        end

        if test -n "$url"
            set url (string trim -- "$url")
        end

        if test -n "$additional_description"
            set additional_description (string trim -- "$additional_description")
        end

        # Debug information (only when verbose)
        if test "$verbose" = true
            echo "  Debug info for $name:"
            echo "    Number of lines: "(count $password_data)
            echo "    First line (password, first 3 chars): "(string sub -l 3 -- "$password_line")"***"

            # Show additional lines (but not their full content)
            for i in (seq 2 (count $password_data))
                set -l line_preview (string sub -l 20 -- "$password_data[$i]")
                echo "    Line $i: $line_preview..."
            end

            if test -n "$username"
                echo "    Username detected: $username"
            end

            if test -n "$url"
                echo "    URL detected: $url"
            end

            if test -n "$additional_description"
                echo "    Additional description: $additional_description"
            end
        end

        # Prepare description with any additional metadata
        set -l description "Imported from pass: $rel_path"

        # Add any additional description to our import description
        if test -n "$additional_description"
            set description "$description\nNote: $additional_description"
        end

        # Prepare command arguments for _pwstore_add
        # Start with the name and the --generate flag if needed
        set -l add_args

        # Add the name first
        set add_args $add_args $pass_name

        # Add the --no-prompt flag and the password
        set add_args $add_args --no-prompt "$password_line"

        # Add username if available
        if test -n "$username"
            set add_args $add_args "--username=$username"
        end

        # Add URL if available
        if test -n "$url"
            set add_args $add_args "--url=$url"
        end

        # Add description as the last argument
        set add_args $add_args "$description"

        # Store in our password store
        if test "$verbose" = true
            echo "  Debug: Running _pwstore_add with arguments: name='$pass_name' password='(redacted)' username='$username' url='$url'"
        end

        if test "$CI" = true; and test "$DEBUG" = true
            echo "  Debug: Full add command arguments: CLASSIFY BY TYPE"
            echo "    - Name: $pass_name"
            echo "    - Username arg: " (test -n "$username" && echo "--username=$username" || echo "None")
            echo "    - URL arg: " (test -n "$url" && echo "--url=$url" || echo "None")
            echo "    - Description length: " (string length "$description")
            echo "    - Password length: " (string length "$password_line")
        end

        set -l add_output (_pwstore_add $add_args 2>&1)
        set -l add_status $status

        if test $add_status -eq 0
            echo "  ✅ Successfully imported"
            if test "$verbose" = true
                echo "    Path: $name"
                test -n "$username" && echo "    Username: $username"
                test -n "$url" && echo "    URL: $url"
            end
            set imported (math $imported + 1)
        else
            echo "  ❌ Failed to import: $(string join ' ' $add_output)"
            # Add more debugging output for CI environments
            if test "$CI" = true
                echo "  Debug: _pwstore_add failed with status: $add_status"
                echo "  Debug: _pwstore_add output: $add_output"
            end
            set failed (math $failed + 1)
        end

        echo "────────────────────────────────────────────────────────────────────────────"
        echo "IMPORT [$current_file_num/$total_files]: COMPLETED"
        echo "────────────────────────────────────────────────────────────────────────────"
    end

    # Move this outside the loop to report cumulative count once at the end
    echo "════════════════════════════════════════════════════════════════════════════"
    echo "IMPORT SUMMARY: $imported passwords imported, $failed failed"
    echo "════════════════════════════════════════════════════════════════════════════"
end

# =============================================================================
# INITIALIZATION
# =============================================================================

# Internal function to initialize the password store
function _pwstore_init
    # Create directory if it doesn't exist
    if not test -d $pwstore_path
        mkdir -p $pwstore_path
    end

    echo "Password store initialized at: $pwstore_path"
    echo ""
    echo "Available commands:"
    echo "  pw add NAME [--username=VALUE] [--url=VALUE] [DESC] - Add or update a password (will prompt for password)"
    echo "  pw gen NAME [LENGTH] [--username=VALUE] [--url=VALUE] [DESC] - Generate and store a password"
    echo "  pw get NAME                    - Copy password to clipboard"
    echo "  pw show NAME                   - Show password in terminal"
    echo "  pw user NAME                   - Copy username to clipboard"
    echo "  pw url NAME                    - Copy URL to clipboard"
    echo "  pw ls, list                    - List all stored passwords"
    echo "  pw rm NAME                     - Delete a password"
    echo "  pw export PATH                 - Export passwords to a file"
    echo "  pw import PATH                 - Import passwords from a file"
    echo "  pw import-pass [DIR]           - Import passwords from standard pass"
    echo "  pw migrate                     - Migrate passwords from old location"
    echo "  pw version                     - Show pwstore version"
    echo "  pw help                        - Show this help message"

    return 0
end

# =============================================================================
# LIST PASSWORDS
# =============================================================================

# Internal function to list all passwords in the password store
function _pwstore_list
    # Define paths for password store
    set -l registry_path $pwstore_path/registry.json.gpg

    # Parse arguments
    set -l show_details false
    set -l debug false

    for arg in $argv
        switch $arg
            case --details
                set show_details true
            case --debug
                set debug true
        end
    end

    # Check if registry exists
    if test ! -f $registry_path
        echo "No password registry found."
        return 1
    end

    # Decrypt the registry directly to memory
    set -l decrypted_content (gpg --quiet --decrypt $registry_path 2>/dev/null)
    if test $status -ne 0
        echo "Failed to decrypt password registry"
        return 1
    end

    # Debug: show raw content
    if $debug
        echo "Raw JSON content:"
        echo $decrypted_content
        echo ---
    end

    # Parse the JSON content
    set -l item_count (echo $decrypted_content | jq 'length')

    if test "$item_count" = 0
        echo "No passwords stored."
        return 0
    end

    # List passwords
    if not $show_details
        # Only show names in a formatted list
        set -l names (echo $decrypted_content | jq -r 'keys[]' | sort)

        # Calculate the longest name for formatting
        set -l longest_name 0
        for name in $names
            set -l length (string length $name)
            if test $length -gt $longest_name
                set longest_name $length
            end
        end

        echo "Stored passwords:"

        # Format for display
        for name in $names
            # Extract username if available
            set -l username (echo $decrypted_content | jq -r ".[\"$name\"].username")

            # Format the username part
            if test "$username" != null -a "$username" != ""
                printf "%-"$longest_name"s  %s\n" $name "($username)"
            else
                printf "%-"$longest_name"s\n" $name
            end
        end
    else
        # Show detailed info for each password
        set -l names (echo $decrypted_content | jq -r 'keys[]' | sort)

        echo "Detailed password information:"
        echo ""

        for name in $names
            set -l item (echo $decrypted_content | jq ".\"$name\"")

            # Extract fields
            set -l username (echo $item | jq -r '.username')
            set -l url (echo $item | jq -r '.url')
            set -l description (echo $item | jq -r '.description')

            # Print details
            echo "Name: $name"

            # Only show fields that are not null
            if test "$username" != null
                echo "  Username: $username"
            end

            if test "$url" != null
                echo "  URL: $url"
            end

            if test "$description" != null
                echo "  Description: $description"
            end

            echo ""
        end
    end

    # Show count
    echo "$item_count passwords stored."
    return 0
end

# =============================================================================
# MIGRATE PASSWORDS
# =============================================================================

# Internal function to migrate passwords from the old location to the new one
function _pwstore_migrate
    # Check if old path exists and is different from current path
    set -l old_path $XDG_CONFIG_HOME/fish/secure/passwords

    if test "$pwstore_path" = "$old_path"
        echo "No migration needed - using default path."
        return 0
    end

    if not test -d "$old_path"
        echo "No passwords found at old location ($old_path)."
        return 1
    end

    # Ensure target directory exists
    if not test -d "$pwstore_path"
        mkdir -p "$pwstore_path"
    end

    # Count files
    set -l old_registry "$old_path/registry.json.gpg"

    if not test -f "$old_registry"
        echo "No password registry found at old location."
        return 1
    end

    read -l -P "Migrate passwords from $old_path to $pwstore_path? [y/N] " confirm

    if not string match -qi y $confirm
        echo "Migration cancelled."
        return 0
    end

    # Copy the registry file
    cp "$old_registry" "$pwstore_path/registry.json.gpg"
    if test $status -ne 0
        echo "Failed to copy password registry."
        return 1
    end

    echo "Passwords successfully migrated from $old_path to $pwstore_path."
    echo "The old password store at $old_path was kept intact."
    echo "You can remove it manually if no longer needed."

    return 0
end
