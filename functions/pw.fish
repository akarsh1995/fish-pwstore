# Main interface for the password store
function pw
    if test (count $argv) -eq 0
        # No arguments, show help
        echo "Password Store"
        echo "Usage: pw COMMAND [ARGS...]"
        echo ""
        echo "Available commands:"
        echo "  add NAME [--username=VALUE] [--url=VALUE] [DESC] - Add or update a password (will prompt for password)"
        echo "  gen NAME [LENGTH] [--username=VALUE] [--url=VALUE] [DESC] - Generate and store a password"
        echo "  get NAME                    - Copy password to clipboard"
        echo "  show NAME                   - Show password in terminal"
        echo "  user NAME                   - Copy username to clipboard"
        echo "  url NAME                    - Copy URL to clipboard"
        echo "  desc NAME                   - Copy description to clipboard"
        echo "  ls, list                    - List all passwords"
        echo "  rm NAME                     - Delete a password"
        echo "  export PATH                 - Export passwords to a file"
        echo "  import PATH                 - Import passwords from a file"
        echo "  import-pass [DIR] [--verbose] - Import passwords from standard pass"
        # Remove the obsolete import-pass-verbose command
        echo "  migrate                     - Migrate passwords from old location"
        echo "  version, --version, -v      - Show pwstore version"
        echo "  help                        - Show this help message"
        return 0
    end

    # Parse the command
    set -l command $argv[1]
    set -l args $argv[2..-1]

    switch $command
        case help
            pw

        case --version -v
            echo "fish-pwstore v1.5.3"

        case add
            if test (count $args) -lt 1
                echo "Usage: pw add NAME [--username=VALUE] [--url=VALUE] [DESCRIPTION]"
                return 1
            end
            _pwstore_add $args

        case gen generate
            if test (count $args) -lt 1
                echo "Usage: pw gen NAME [LENGTH] [--username=VALUE] [--url=VALUE] [DESCRIPTION]"
                return 1
            end
            _pwstore_add --generate $args

        case get
            if test (count $args) -lt 1
                echo "Usage: pw get NAME"
                return 1
            end
            _pwstore_get $args[1] --copy

        case show
            if test (count $args) -lt 1
                echo "Usage: pw show NAME"
                return 1
            end
            _pwstore_get $args[1] --show

        case user username email
            if test (count $args) -lt 1
                echo "Usage: pw user NAME"
                return 1
            end
            _pwstore_get $args[1] --username

        case url link website
            if test (count $args) -lt 1
                echo "Usage: pw url NAME"
                return 1
            end
            _pwstore_get $args[1] --url

        case desc description
            if test (count $args) -lt 1
                echo "Usage: pw desc NAME"
                return 1
            end
            _pwstore_get $args[1] --description

        case ls list
            _pwstore_list $args

        case rm delete remove
            if test (count $args) -lt 1
                echo "Usage: pw rm NAME [--force]"
                return 1
            end
            _pwstore_delete $args

        case export
            if test (count $args) -lt 1
                echo "Usage: pw export PATH"
                return 1
            end
            _pwstore_export $args

        case import
            if test (count $args) -lt 1
                echo "Usage: pw import PATH [--merge|--overwrite]"
                return 1
            end
            _pwstore_import $args

        case init
            _pwstore_init

        case migrate
            _pwstore_migrate

        case version
            echo "fish-pwstore v1.5.3"

        case import-pass
            # Check if --verbose flag is present in arguments
            if contains -- --verbose $args
                # Remove --verbose from args to avoid passing it twice
                set -l filtered_args
                for arg in $args
                    if test "$arg" != --verbose
                        set filtered_args $filtered_args $arg
                    end
                end
                _pwstore_import_from_pass $filtered_args --verbose
            else
                _pwstore_import_from_pass $args
            end

        case "*"
            echo "Unknown command: $command"
            echo "Run 'pw help' to see available commands"
            return 1
    end
end
