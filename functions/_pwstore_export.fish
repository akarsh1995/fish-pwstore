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
