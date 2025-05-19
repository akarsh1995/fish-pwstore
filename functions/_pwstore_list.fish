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
