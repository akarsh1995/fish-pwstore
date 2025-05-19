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
    
    for arg in $argv[2..-1]
        switch $arg
            case "--copy"
                set copy_to_clipboard true
                set show_password false
            case "--show"
                set show_password true
                set copy_to_clipboard false
            case "--username"
                set get_username true
                set copy_to_clipboard true
                set show_password false
            case "--url"
                set get_url true
                set copy_to_clipboard true
                set show_password false
            case "--description" "--desc"
                set get_description true
                set copy_to_clipboard true
                set show_password false
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
    
    if test "$password_data" = "null"
        echo "Password '$name' not found."
        return 1
    end
    
    # Extract the value based on what was requested
    if $get_username
        set -l username (echo $password_data | jq -r '.username')
        if test "$username" = "null" -o "$username" = ""
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
        if test "$url" = "null" -o "$url" = ""
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
        if test "$description" = "null" -o "$description" = ""
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
        if test "$username" != "null" -a "$username" != ""
            echo "Username: $username"
        end
        
        # Show URL if available
        if test "$url" != "null" -a "$url" != ""
            echo "URL: $url"
        end
        
        # Show description if available
        if test "$description" != "null" -a "$description" != ""
            echo "Description: $description"
        end
    end
    
    return 0
end
