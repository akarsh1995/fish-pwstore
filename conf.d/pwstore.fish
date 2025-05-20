# fish-pwstore - A secure GPG-based password manager for the Fish shell
# Repository: https://github.com/akarsh1995/fish-pwstore

# Only load in interactive sessions or CI environments (speeds up shell startup)
if not status is-interactive && test "$CI" != true
    exit
end


# if no XDG_CONFIG_HOME is set, use ~/.config
if not set -q XDG_CONFIG_HOME
    set -gx XDG_CONFIG_HOME $HOME/.config
end

# Set default configuration variables (can be overridden by user)
set -q pwstore_path || set -g pwstore_path $XDG_CONFIG_HOME/fish/secure/passwords
set -q pwstore_password_length || set -g pwstore_password_length 20

# Default GPG recipient (uses current user if not set)
if not set -q pwstore_gpg_recipient
    # Try to get a valid GPG key
    set -l first_key (gpg --list-keys --with-colons 2>/dev/null | grep '^pub:' | head -n 1 | cut -d: -f5)

    if test -n "$first_key"
        # Use first available key if we found one
        set -g pwstore_gpg_recipient $first_key
    else
        # Fallback to user email format
        set -l current_user (whoami)
        set -l current_host (hostname)
        set -g pwstore_gpg_recipient "$current_user <$current_user@$current_host>"
    end
end

# Helper function to initialize password store - this is internal
# to the pwstore.fish file and should not be confused with the user-facing
# _pwstore_init.fish function
function __pwstore_init_dir
    # This ensures the password store directory exists
    if not test -d $pwstore_path
        mkdir -p $pwstore_path
    end
end

# Fisher event handlers
function _pwstore_install --on-event pwstore_install
    set_color green
    echo "Installing fish-pwstore..."
    set_color normal

    # Initialize the password store
    __pwstore_init_dir

    echo "Password store initialized at: $pwstore_path"
    echo ""
    echo "Commands are available through the 'pw' function:"
    echo "Run 'pw help' to see available commands"
end

function _pwstore_update --on-event pwstore_update
    set_color yellow
    echo "Updating fish-pwstore..."
    set_color normal

    # Run initialization again to ensure password store exists
    __pwstore_init_dir

    # Check for and migrate any old configuration if needed
    if test -d "$XDG_CONFIG_HOME/fish/secure/passwords" && test "$pwstore_path" != "$XDG_CONFIG_HOME/fish/secure/passwords"
        echo "Found passwords in old location. Run 'pw migrate' if you wish to migrate them."
    end
end

function _pwstore_uninstall --on-event pwstore_uninstall
    set_color red
    echo "Uninstalling fish-pwstore..."
    set_color normal

    # Clean up can be done here if needed
    # Note: We don't delete the passwords by default to prevent data loss
    echo "Your passwords are still stored in $pwstore_path"
    echo "You can manually remove this directory if you wish to delete all your passwords."

    # Clean up functions and completions
    functions --erase (functions --all | string match --entire -r '^_?pwstore')

    # Remove any universal variables we've set (keeping passwords intact)
    set -e pwstore_password_length
    set -e pwstore_clipboard_time

    # Note: we don't erase pwstore_path to prevent data loss if user reinstalls

    set_color cyan
    echo "fish-pwstore uninstalled."
    set_color normal
end
