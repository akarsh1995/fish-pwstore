# Function to import passwords from a GPG-encrypted backup file
function pwstore_import
    # Define paths for password store
    set -l store_path $XDG_CONFIG_HOME/fish/secure/passwords
    set -l registry_path $store_path/registry.json.gpg
    
    # Check arguments
    if test (count $argv) -lt 1
        echo "Usage: pwstore_import IMPORT_PATH [--merge] [--overwrite]"
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
    
    # Ensure the directory exists
    mkdir -p $store_path
    
    # Handle import based on merge flag
    if $merge; and test -f $registry_path
        # Merge with existing registry
        
        # Decrypt both files
        set -l current_content (gpg --quiet --decrypt $registry_path 2>/dev/null)
        if test $status -ne 0
            echo "Failed to decrypt current password registry"
            return 1
        end
        
        set -l import_content (gpg --quiet --decrypt $import_path 2>/dev/null)
        if test $status -ne 0
            echo "Failed to decrypt import file"
            return 1
        end
        
        # Merge the JSON files (import content will override duplicates)
        set -l merged_content (echo $current_content | jq -s --argjson import "$import_content" '.[0] * $import')
        
        # Re-encrypt the merged content
        echo $merged_content | gpg --quiet --yes --recipient (echo "$(whoami) <$(whoami)@$(hostname)>") --encrypt --output $registry_path
        
        if test $status -ne 0
            echo "Failed to encrypt merged password registry"
            return 1
        end
        
        echo "Passwords imported and merged successfully"
    else
        # Direct replacement or new file
        cp $import_path $registry_path
        
        if test $status -ne 0
            echo "Failed to copy import file to registry"
            return 1
        end
        
        echo "Passwords imported successfully (existing passwords replaced)"
    end
end
