# Changelog

## v1.5.3 - 2025-05-19

### Fixed
- Fixed path handling when importing nested directories from pass
- Implemented `realpath`/`grealpath` to reliably determine relative paths between password files and the pass directory
- Added regex escaping for paths with special characters to ensure proper path resolution
- Removed hardcoded path references for better compatibility with all pass directories
- Improved fallback to direct GPG decryption when pass command fails
- Enhanced verbose mode with additional debugging information
- Added proper handling of special characters in paths
- Fixed local variable scope issue with `pass_dir` variable

### Added
- Added comprehensive tests in the tests directory for path resolution and pass integration

## v1.5.2 - 2025-05-18

### Fixed
- Fixed "Failed to save the password registry" GPG encryption issues
- Enhanced GPG error reporting with detailed error messages
- Added robust GPG recipient detection for better key management
- Improved directory permission checking to prevent write errors

### Added
- New GPG diagnostic tool for troubleshooting encryption issues
- Comprehensive troubleshooting section in documentation
- Smarter GPG key detection that uses existing keys when available

## v1.5.1 - 2025-05-18

### Enhanced
- Improved password import from standard pass utility
- Added better metadata extraction from pass entries
- More detailed import feedback with success/failure indicators
- Added automatic fallback to direct GPG decryption if pass command fails
- Better description handling with support for notes/description fields

## v1.0.0 - 2025-05-18

### Added
- Initial release of fish-pwstore
- GPG-based secure password storage
- Add, generate, retrieve, and delete passwords
- Copy passwords to clipboard
- Store usernames and URLs alongside passwords
- List stored passwords with details view
- Export and import password database
- Import from standard pass utility
- Tab completion for commands and password names

## v1.1.0 - 2025-05-18

### Added
- Configurable password store path with `pwstore_path` variable
- Configurable password length for generation with `pwstore_password_length` variable
- Configurable clipboard timeout with `pwstore_clipboard_time` variable
- Migration command to move passwords from old location to new one
- Full Fisher plugin compatibility

### Changed
- Improved error handling and feedback
- Better compatibility with Fish plugin managers
- Updated documentation with configuration options

### Fixed
- Issue with password store initialization at first run

## v1.5.0 - 2025-05-18

### Changed
- Removed auto-clearing of clipboard contents for improved user convenience
- Clipboard contents now remain until manually cleared or overwritten

## v1.4.0 - 2025-05-18

### Added
- Command to retrieve password descriptions with `pw desc NAME`
- Tab completion for the new `desc` command

### Enhanced
- `pw show` now displays username, URL, and description alongside the password for better context
- Improved cross-platform support by using Fish's built-in `fish_clipboard_copy` instead of platform-specific `pbcopy`

## v1.3.0 - 2025-05-18

### Added
- Configurable GPG recipient with `pwstore_gpg_recipient` variable, allowing use of specific GPG keys for encryption

## v1.2.1 - 2025-05-18

### Fixed
- Fixed critical issue with regex escaping in `_pwstore_import_from_pass.fish` that caused installation errors

## v1.2.0 - 2025-05-18

### Changed
- Refactored function naming convention to follow Fisher best practices
- All internal functions now use underscore prefix (`_pwstore_*`)
- Better separation between user-facing commands and internal functions
- Improved plugin organization

### Security
- Maintained backward compatibility with existing password stores
- No changes to encryption or storage mechanism