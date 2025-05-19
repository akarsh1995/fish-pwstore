# Completions for pw function (password store wrapper)

# Helper function to get password names
function __pw_password_names
    set -l registry_path $pwstore_path/registry.json.gpg
    if test -f $registry_path
        gpg --quiet --decrypt $registry_path 2>/dev/null | jq -r 'keys[]'
    end
end

# Define main commands
complete -c pw -f -n "__fish_use_subcommand" -a "add" -d "Add or update a password"
complete -c pw -f -n "__fish_use_subcommand" -a "gen" -d "Generate and store a password"
complete -c pw -f -n "__fish_use_subcommand" -a "get" -d "Copy password to clipboard"
complete -c pw -f -n "__fish_use_subcommand" -a "show" -d "Show password in terminal"
complete -c pw -f -n "__fish_use_subcommand" -a "user" -d "Copy username to clipboard"
complete -c pw -f -n "__fish_use_subcommand" -a "url" -d "Copy URL to clipboard"
complete -c pw -f -n "__fish_use_subcommand" -a "desc" -d "Copy description to clipboard"
complete -c pw -f -n "__fish_use_subcommand" -a "ls" -d "List all passwords"
complete -c pw -f -n "__fish_use_subcommand" -a "list" -d "List all passwords"
complete -c pw -f -n "__fish_use_subcommand" -a "rm" -d "Delete a password"
complete -c pw -f -n "__fish_use_subcommand" -a "export" -d "Export passwords to a file"
complete -c pw -f -n "__fish_use_subcommand" -a "import" -d "Import passwords from a file"
complete -c pw -f -n "__fish_use_subcommand" -a "import-pass" -d "Import passwords from standard pass"
complete -c pw -f -n "__fish_use_subcommand" -a "init" -d "Initialize the password store"
complete -c pw -f -n "__fish_use_subcommand" -a "migrate" -d "Migrate passwords from old location"
complete -c pw -f -n "__fish_use_subcommand" -a "version" -d "Show pwstore version"
complete -c pw -f -n "__fish_use_subcommand" -a "help" -d "Show help message"

# Subcommand completions
complete -c pw -f -n "__fish_seen_subcommand_from get show user url desc rm add" -a "(__pw_password_names)"
complete -c pw -f -n "__fish_seen_subcommand_from rm" -l force -d "Delete without confirmation"

# List command options
complete -c pw -f -n "__fish_seen_subcommand_from ls list" -l details -d "Show additional details"

# Import command options
complete -c pw -f -n "__fish_seen_subcommand_from import" -a "(__fish_complete_path)" -d "Import file path"
complete -c pw -f -n "__fish_seen_subcommand_from import" -l merge -d "Combine with existing passwords (default)"
complete -c pw -f -n "__fish_seen_subcommand_from import" -l overwrite -d "Replace all existing passwords"

# Export command options
complete -c pw -f -n "__fish_seen_subcommand_from export" -a "(__fish_complete_path)" -d "Export file path"

# Import-pass command options
complete -c pw -f -n "__fish_seen_subcommand_from import-pass" -a "(__fish_complete_directories)" -d "Pass directory"
complete -c pw -f -n "__fish_seen_subcommand_from import-pass" -a "--verbose" -d "Show detailed import information"
