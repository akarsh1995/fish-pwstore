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
fisher install username/pwstore
```

> ⚠️ Replace "username" with your actual GitHub username when you publish the plugin.

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
- `pw ls` or `pw list` - List all stored passwords in a formatted table
- `pw rm NAME` - Delete a password
- `pw export PATH` - Export passwords to a file
- `pw import PATH` - Import passwords from a file
- `pw import-pass [DIR]` - Import passwords from standard pass
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

## Security

- All passwords are encrypted using GPG with your personal key
- Passwords are never stored in plain text on disk
- When copying to clipboard, passwords are not displayed on screen
- Passwords are entered via masked prompts to prevent terminal history leakage
- All sensitive operations require GPG decryption

## Storage

Passwords are stored in:
`$XDG_CONFIG_HOME/fish/secure/passwords/registry.json.gpg`

## License

[MIT License](LICENSE)

## Author

[Your Name](https://github.com/yourusername)
