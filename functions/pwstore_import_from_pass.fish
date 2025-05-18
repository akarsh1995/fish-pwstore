# Function to import passwords from standard pass utility
function pwstore_import_from_pass
    set -l pass_dir $HOME/.password-store
    
    # Check if specified a custom pass directory
    if test (count $argv) -ge 1; and test -d "$argv[1]"
        set pass_dir "$argv[1]"
    end
    
    # Check if pass directory exists
    if not test -d $pass_dir
        echo "Pass directory not found: $pass_dir"
        echo "Usage: pwstore_import_from_pass [PASS_DIRECTORY]"
        return 1
    end
    
    # Count the number of password files
    set -l password_files (find $pass_dir -name "*.gpg" | wc -l)
    
    echo "Found $password_files password files in $pass_dir"
    read -l -P "Proceed with import? [y/N] " confirm
    
    if not string match -qi "y" $confirm
        echo "Import cancelled."
        return 0
    end
    
    # Initialize counter
    set -l imported 0
    set -l failed 0
    
    # Find all .gpg files
    for file in (find $pass_dir -name "*.gpg")
        # Extract the relative path from the pass directory (keeping .gpg extension for 'pass show')
        set -l rel_path (string replace -r "^$pass_dir/" "" $file)
        
        # Create the name for our password store (without .gpg extension)
        set -l name (string replace -r "\.gpg\$" "" $rel_path)
        
        # Keep the original hierarchy with slashes
        # No need to replace slashes with dots
        
        echo "Importing: $name"
        
        # For 'pass show', we need to remove the .gpg extension
        set -l pass_name (string replace -r "\.gpg\$" "" $rel_path)
        
        # Attempt to decrypt the pass file
        # Use the specific pass directory when calling pass
        # The output is automatically split into lines in Fish
        set -l password_data (env PASSWORD_STORE_DIR=$pass_dir pass show $pass_name 2>/dev/null)
        
        if test $status -ne 0
            echo "  ❌ Failed to decrypt pass file: $rel_path"
            set failed (math $failed + 1)
            continue
        end
        
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
        if begin test -n "$PWSTORE_DEBUG"; or string match -q -- "--verbose" $argv; end
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
        
        # Prepare command arguments for pwstore_add
        set -l add_args $name --no-prompt $password_line
        
        # Add username if available
        if test -n "$username"
            set add_args $add_args --username=$username
        end
        
        # Add URL if available
        if test -n "$url"
            set add_args $add_args --url=$url
        end
        
        # Add description as the last argument
        set add_args $add_args "$description"
        
        # Store in our password store
        pwstore_add $add_args >/dev/null
        
        if test $status -eq 0
            echo "  ✅ Successfully imported"
            set imported (math $imported + 1)
        else
            echo "  ❌ Failed to import"
            set failed (math $failed + 1)
        end
    end
    
    echo "Import complete: $imported passwords imported, $failed failed"
end
