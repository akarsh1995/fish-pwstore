# Function to delete a password from the password store
function pwstore_delete
    # Define paths for password store
    set -l store_path $XDG_CONFIG_HOME/fish/secure/passwords
    set -l registry_path $store_path/registry.json.gpg
    
    # Check arguments
    if test (count $argv) -lt 1
        echo "Usage: pwstore_delete NAME [--force]"
        return 1
    end
    
    set -l name $argv[1]
    set -l force false
    
    for arg in $argv[2..-1]
        if test "$arg" = "--force"
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
    if not echo $decrypted_content | jq -e --arg name "$name" 'has($name)' > /dev/null
        echo "Password for '$name' not found"
        return 1
    end
    
    # Get description for confirmation
    set -l description (echo $decrypted_content | jq -r --arg name "$name" '.[$name].description')
    
    # Confirm deletion unless --force is used
    if not $force
        read -l -P "Delete password for '$name' ($description)? [y/N] " confirm
        if not string match -qi "y" $confirm
            echo "Operation cancelled."
            return 0
        end
    end
    
    # Remove the entry from the registry
    echo $decrypted_content | jq --arg name "$name" 'del(.[$name])' | \
       gpg --quiet --yes --recipient (echo "$(whoami) <$(whoami)@$(hostname)>") --encrypt --output $registry_path
    
    if test $status -ne 0
        echo "Failed to update password registry"
        return 1
    end
    
    echo "Password for '$name' deleted successfully"
end
