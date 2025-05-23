# Pass Import User Guide

This guide helps you import passwords from the standard pass password manager into fish-pwstore.

## Basic Usage

```fish
# Import from default pass location (~/.password-store)
pw import-pass

# Import from a specific pass directory
pw import-pass /path/to/password-store

# Import with verbose output for troubleshooting
pw import-pass --verbose
```

## Handling Nested Directories

fish-pwstore supports importing passwords from nested directories in pass. The hierarchical structure is preserved during import.

The import process uses multiple fallback methods for path resolution to ensure cross-platform compatibility:

1. First tries `realpath` (common on Linux systems)
2. Then tries `grealpath` (GNU coreutils on macOS)
3. Falls back to Python's `os.path.abspath` if available
4. Uses built-in Fish shell capabilities as a last resort

This robust approach ensures correct path resolution across different operating systems, even in environments with limited command availability like CI systems. Special characters in paths are properly handled using regex escaping to prevent errors during path manipulation.

For example, if you have passwords stored in pass as:
```
~/.password-store/email/work/account.gpg
~/.password-store/banking/checking/account.gpg
```

After importing, you can access them in fish-pwstore as:
```fish
pw get email/work/account
pw get banking/checking/account
```

## Troubleshooting

### 1. "Failed to decrypt pass file" errors

If you see errors about decrypting pass files:

- Make sure you have the correct GPG key to decrypt the pass files
- Try running `pw import-pass --verbose` to see detailed information
- Run `gpg --list-keys` to verify your GPG keys are available

### 2. No passwords were imported

If no passwords were imported:

- Check if your pass directory contains .gpg files
- Ensure the path to your pass directory is correct

### 3. Path resolution issues

If you encounter path resolution problems:

- Try using the `--verbose` flag to see how paths are being resolved
- Ensure you have at least one of the supported path resolution methods available:
  - `realpath` or `grealpath` commands
  - Python (either version 2 or 3)
  - The `readlink -f` command

On macOS, you can install GNU coreutils (which includes `grealpath`) with:
```
brew install coreutils
```
- Try specifying the full path: `pw import-pass /full/path/to/password-store`

### 3. Path issues with nested directories

If you have issues with nested directories:

- Run `pw import-pass --verbose` to see the paths being processed
- Check that the directory structure in pass is as expected
- If importing from a custom location, make sure to specify the root password store directory
- The importer supports paths with leading dots (like `.dotfolder/secret`) and will preserve the exact structure
- Hidden directories (those starting with a dot) will be imported correctly

### 4. Testing your import

To test if your import will work correctly:

```fish
./test_pass_import_nested.fish
```

This will create a mock pass store with nested directories and attempt to import it, showing you detailed information about the process.

## Data Format

When importing from pass:

- The first line of each file is treated as the password
- Lines starting with `username:`, `user:`, `login:`, or `email:` are imported as the username
- Lines starting with `url:`, `website:`, `site:`, or `link:` are imported as the URL
- Lines starting with `description:`, `desc:`, `notes:`, or `note:` are imported as the description
- Other lines are added to the description field

## After Importing

After importing passwords from pass, you can:

1. List all imported passwords: `pw ls`
2. Show details of a specific password: `pw show name`
3. Retrieve a password: `pw get name`
