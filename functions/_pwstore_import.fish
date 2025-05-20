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
