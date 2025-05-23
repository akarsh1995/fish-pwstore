# Internal function to import passwords from the standard pass password manager utility
# This function imports passwords, usernames, URLs, and descriptions from a pass password store
# Usage: _pwstore_import_from_pass [PASS_DIRECTORY] [--verbose] [--no-confirm]
function _pwstore_import_from_pass
    # Check if PASSWORD_STORE_DIR is set, otherwise use default
    # Define pass_dir as a local variable with the -l flag, but assign it outside the if block
    # so it remains accessible throughout the function
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

    # Make sure we have access to the _pwstore_add function
    # Source it if it's not already loaded
    if not functions -q _pwstore_add
        # Try to source the function
        set -l script_dir (dirname (status -f))
        if test -f "$script_dir/_pwstore_add.fish"
            source "$script_dir/_pwstore_add.fish"
        end

        # Check if we successfully loaded the function
        if not functions -q _pwstore_add
            echo "Error: Could not load _pwstore_add function."
            echo "Make sure you're running this command from the fish-pwstore directory."
            return 1
        end
    end # Source our path utility functions
    set -l script_dir (dirname (status -f))
    if test -f "$script_dir/_pwstore_path_utils.fish"
        source "$script_dir/_pwstore_path_utils.fish"
    end

    # If we failed to source the utility functions, define them directly for backward compatibility
    if not functions -q _pwstore_resolve_path
        function _pwstore_resolve_path
            set -l path_to_resolve $argv[1]
            # Use same implementation as in _pwstore_path_utils.fish
            if command -sq realpath
                realpath "$path_to_resolve" 2>/dev/null
                and return 0
            end

            if command -sq grealpath
                command grealpath "$path_to_resolve" 2>/dev/null
                and return 0
            end

            if type -q python3
                python3 -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null
                and return 0
            end

            if type -q python
                python -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null
                and return 0
            end

            if command -sq readlink
                readlink -f "$path_to_resolve" 2>/dev/null
                and return 0
            end

            if test -d "$path_to_resolve"
                pushd "$path_to_resolve" >/dev/null
                pwd
                popd >/dev/null
                and return 0
            end

            if test -f "$path_to_resolve"
                set -l dir_name (dirname "$path_to_resolve")
                set -l base_name (basename "$path_to_resolve")
                pushd "$dir_name" >/dev/null
                echo (pwd)/"$base_name"
                popd >/dev/null
                and return 0
            end

            echo "$path_to_resolve"
            return 0
        end
    end

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
