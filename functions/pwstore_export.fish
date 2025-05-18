# Function to export passwords to a GPG-encrypted backup file
function pwstore_export
    # Define paths for password store
    set -l store_path $XDG_CONFIG_HOME/fish/secure/passwords
    set -l registry_path $store_path/registry.json.gpg
    
    # Check arguments
    if test (count $argv) -lt 1
        echo "Usage: pwstore_export EXPORT_PATH"
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
    
    # Directly copy the encrypted file 
    cp $registry_path $export_path
    
    if test $status -ne 0
        echo "Failed to export passwords"
        return 1
    end
    
    echo "Passwords exported successfully to: $export_path"
end
