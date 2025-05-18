# Function to retrieve a password from the password store
function pwstore_get
    # Define paths for password store
    set -l store_path $XDG_CONFIG_HOME/fish/secure/passwords
    set -l registry_path $store_path/registry.json.gpg
    
    # Check arguments
    if test (count $argv) -lt 1
        echo "Usage: pwstore_get NAME [--copy] [--show]"
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
    
    for arg in $argv[2..-1]
        switch $arg
            case --copy
                set copy_to_clipboard true
            case --show
                set show_password true
                set copy_to_clipboard false
            case --username
                set get_username true
            case --url
                set get_url true
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
    if not echo $decrypted_content | jq -e --arg name "$name" 'has($name)' > /dev/null
        echo "Password for '$name' not found"
        return 1
    end
    
    # Get the password and other details
    set -l password (echo $decrypted_content | jq -r --arg name "$name" '.[$name].password')
    set -l description (echo $decrypted_content | jq -r --arg name "$name" '.[$name].description')
    set -l username (echo $decrypted_content | jq -r --arg name "$name" '.[$name].username // ""')
    set -l url (echo $decrypted_content | jq -r --arg name "$name" '.[$name].url // ""')
    
    # Handle request for username specifically
    if $get_username
        if test -z "$username"
            echo "No username/email found for '$name'"
            return 1
        end
        
        if $copy_to_clipboard
            if command -sq pbcopy
                echo -n $username | pbcopy
                echo "Username/Email for '$name' copied to clipboard"
            else if command -sq xclip
                echo -n $username | xclip -selection clipboard
                echo "Username/Email for '$name' copied to clipboard"
            else
                echo "Could not copy to clipboard - no clipboard utility found (pbcopy/xclip)"
                echo "Username/Email: $username"
            end
        else
            echo "Username/Email: $username"
        end
        return 0
    end
    
    # Handle request for URL specifically
    if $get_url
        if test -z "$url"
            echo "No URL found for '$name'"
            return 1
        end
        
        if $copy_to_clipboard
            if command -sq pbcopy
                echo -n $url | pbcopy
                echo "URL for '$name' copied to clipboard"
            else if command -sq xclip
                echo -n $url | xclip -selection clipboard
                echo "URL for '$name' copied to clipboard"
            else
                echo "Could not copy to clipboard - no clipboard utility found (pbcopy/xclip)"
                echo "URL: $url"
            end
        else
            echo "URL: $url"
        end
        return 0
    end
    
    # Show or copy the password as requested
    if $show_password
        echo "Description: $description"
        if test -n "$username"
            echo "Username/Email: $username" 
        end
        if test -n "$url"
            echo "URL: $url"
        end
        echo "Password: $password"
    else if $copy_to_clipboard
        if command -sq pbcopy
            echo -n $password | pbcopy
            echo "Password for '$name' copied to clipboard"
            if test -n "$username"
                echo "Username/Email: $username"
            end
            if test -n "$url"
                echo "URL: $url"
            end
        else if command -sq xclip
            echo -n $password | xclip -selection clipboard
            echo "Password for '$name' copied to clipboard"
            if test -n "$username"
                echo "Username/Email: $username"
            end
            if test -n "$url"
                echo "URL: $url"
            end
        else
            echo "Could not copy to clipboard - no clipboard utility found (pbcopy/xclip)"
            echo "Description: $description"
            if test -n "$username"
                echo "Username/Email: $username"
            end
            if test -n "$url"
                echo "URL: $url"
            end
            echo "Password: $password"
        end
    end
end
