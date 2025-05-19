# pwstore

A secure GPG-based password manager for the Fish shell.

## Features

- Store passwords securely using GPG encryption
- Generate secure random passwords
- Copy passwords to clipboard without displaying them
- List all stored passwords in a beautiful table format
- Import/export functionality for backups
- Import passwords from the standard pass utility
- Tab completion for all commands
- Store and retrieve usernames and URLs alongside passwords

## Installation

Install with [Fisher](https://github.com/jorgebucaran/fisher):

```fish
fisher install akarsh1995/fish-pwstore
```

## Requirements

- [Fish shell](https://fishshell.com) (3.0.0+)
- [GPG](https://gnupg.org/) for encryption
- [jq](https://stedolan.github.io/jq/) for JSON processing
- Optional: [pass](https://www.passwordstore.org/) for importing existing passwords

## Usage

The password store is accessed through the `pw` command:

```fish
pw COMMAND [ARGS...]
```

### Available Commands

- `pw add NAME [--username=VALUE] [--url=VALUE] [DESC]` - Add/update a password (will prompt for password)
- `pw gen NAME [LENGTH] [--username=VALUE] [--url=VALUE] [DESC]` - Generate and store a password
- `pw get NAME` - Copy password to clipboard
- `pw show NAME` - Show password in terminal
- `pw user NAME` - Copy username/email to clipboard
- `pw url NAME` - Copy URL to clipboard
- `pw desc NAME` - Copy description to clipboard
- `pw ls` or `pw list` - List all stored passwords in a formatted table
- `pw rm NAME` - Delete a password
- `pw export PATH` - Export passwords to a file
- `pw import PATH` - Import passwords from a file
- `pw import-pass [DIR] [--verbose]` - Import passwords from standard pass
- `pw init` - Initialize the password store
- `pw help` - Show help message

### Examples

Add a password (will prompt for password):
```fish
pw add github "GitHub account password"
```

Add a password with username (will prompt for password):
```fish
pw add github --username=user@example.com "GitHub account password"
```

Add a password with username and URL (will prompt for password):
```fish
pw add github --username=user@example.com --url=https://github.com "GitHub account password"
```

Get a password description:
```fish
pw desc github
```

Generate a random password:
```fish
pw gen netflix 16 "Netflix account password"
```

Generate a random password with username:
```fish
pw gen netflix 16 --username=user@example.com "Netflix account password" 
```

Generate a random password with username and URL:
```fish
pw gen netflix 16 --username=user@example.com --url=https://netflix.com "Netflix account password" 
```

Retrieve a password (copies to clipboard):
```fish
pw get github
```

Display a password in the terminal:
```fish
pw show github
```

Copy the username/email to clipboard:
```fish
pw user github
```

Copy the URL to clipboard:
```fish
pw url github
```

List all stored passwords in a formatted table:
```fish
pw ls
```

Show additional details including update timestamps:
```fish
pw ls --details
```

Delete a password:
```fish
pw rm github
```

Export passwords for backup:
```fish
pw export ~/backup/passwords.gpg
```

Import passwords:
```fish
pw import ~/backup/passwords.gpg
```

Import from standard pass password manager:
```fish
# Import from default pass location (~/.password-store)
pw import-pass

# Import from a specific pass directory
pw import-pass /path/to/password-store

# Import with verbose output
pw import-pass --verbose
```

See [PASS_IMPORT_GUIDE.md](PASS_IMPORT_GUIDE.md) for detailed instructions on importing from pass, including handling nested directories and troubleshooting.

## Configuration

You can customize pwstore behavior by setting these variables in your `config.fish`:

```fish
# Change the password storage location
set -U pwstore_path $HOME/.password-store

# Change the default generated password length (default: 20)
set -U pwstore_password_length 24

# Set a specific GPG recipient (default: first available key or current user)
# Format can be name, email, or key ID
set -U pwstore_gpg_recipient "Your Name <your.email@example.com>"
# Or use a specific key ID (recommended for more reliable operation)
# set -U pwstore_gpg_recipient "0xA1B2C3D4E5F6G7H8"
```

## Security

- All passwords are encrypted using GPG with your personal key
- Passwords are never stored in plain text on disk
- When copying to clipboard, passwords are not displayed on screen
- Passwords are entered via masked prompts to prevent terminal history leakage
- All sensitive operations require GPG decryption
- Clipboard contents remain until manually cleared or overwritten

## Storage

By default, passwords are stored in:
`$XDG_CONFIG_HOME/fish/secure/passwords/registry.json.gpg`

You can change this location by setting the `pwstore_path` variable.

## Troubleshooting

### GPG Encryption Issues

If you encounter GPG-related issues such as "Failed to save the password registry" or other encryption problems:

1. Run the included diagnostic script:
   ```fish
   ./debug_pwstore_gpg.fish
   ```
   This will provide detailed information about your GPG setup and potential issues.

2. Create a GPG key if you don't have one:
   ```fish
   gpg --gen-key
   ```
   Follow the prompts to create a new key pair.

3. Set a specific GPG recipient using your key ID:
   ```fish
   set -U pwstore_gpg_recipient "YOUR_KEY_ID"
   ```
   You can find your key ID by running `gpg --list-keys`.

4. Check directory permissions:
   ```fish
   ls -la $pwstore_path
   ```
   Make sure you have write permissions for the directory.

### Password Import Issues

For issues with importing passwords from the standard pass password manager:

1. See the detailed guide:
   ```fish
   less PASS_IMPORT_GUIDE.md
   ```

2. Run the test suite to verify functionality:
   ```fish
   fish ./tests/run_tests.fish
   ```

   Or run individual test scripts:
   ```fish
   fish ./tests/test_realpath_import.fish
   fish ./tests/test_pass_import_integration.fish
   ```

3. Use verbose mode for more information:
   ```fish
   pw import-pass --verbose
   ```

## License

[MIT License](LICENSE)

## Author

[Akarsh Jain](https://github.com/akarsh1995)
