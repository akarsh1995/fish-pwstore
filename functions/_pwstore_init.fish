# Internal function to initialize the password store
function _pwstore_init
    # Create directory if it doesn't exist
    if not test -d $pwstore_path
        mkdir -p $pwstore_path
    end

    echo "Password store initialized at: $pwstore_path"
    echo ""
    echo "Available commands:"
    echo "  pw add NAME [--username=VALUE] [--url=VALUE] [DESC] - Add or update a password (will prompt for password)"
    echo "  pw gen NAME [LENGTH] [--username=VALUE] [--url=VALUE] [DESC] - Generate and store a password"
    echo "  pw get NAME                    - Copy password to clipboard"
    echo "  pw show NAME                   - Show password in terminal"
    echo "  pw user NAME                   - Copy username to clipboard"
    echo "  pw url NAME                    - Copy URL to clipboard"
    echo "  pw ls, list                    - List all stored passwords"
    echo "  pw rm NAME                     - Delete a password"
    echo "  pw export PATH                 - Export passwords to a file"
    echo "  pw import PATH                 - Import passwords from a file"
    echo "  pw import-pass [DIR]           - Import passwords from standard pass"
    echo "  pw migrate                     - Migrate passwords from old location"
    echo "  pw version                     - Show pwstore version"
    echo "  pw help                        - Show this help message"

    return 0
end
