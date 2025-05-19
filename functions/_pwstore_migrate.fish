# Internal function to migrate passwords from the old location to the new one
function _pwstore_migrate
    # Check if old path exists and is different from current path
    set -l old_path $XDG_CONFIG_HOME/fish/secure/passwords
    
    if test "$pwstore_path" = "$old_path"
        echo "No migration needed - using default path."
        return 0
    end

    if not test -d "$old_path"
        echo "No passwords found at old location ($old_path)."
        return 1
    end
    
    # Ensure target directory exists
    if not test -d "$pwstore_path"
        mkdir -p "$pwstore_path"
    end
    
    # Count files
    set -l old_registry "$old_path/registry.json.gpg"
    
    if not test -f "$old_registry"
        echo "No password registry found at old location."
        return 1
    end
    
    read -l -P "Migrate passwords from $old_path to $pwstore_path? [y/N] " confirm
    
    if not string match -qi "y" $confirm
        echo "Migration cancelled."
        return 0
    end
    
    # Copy the registry file
    cp "$old_registry" "$pwstore_path/registry.json.gpg"
    if test $status -ne 0
        echo "Failed to copy password registry."
        return 1
    end
    
    echo "Passwords successfully migrated from $old_path to $pwstore_path."
    echo "The old password store at $old_path was kept intact."
    echo "You can remove it manually if no longer needed."
    
    return 0
end
