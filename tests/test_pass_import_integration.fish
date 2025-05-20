#!/usr/bin/env fish

# Set environment for pass
export PASSWORD_STORE_DIR=~/.password-store

# Initialize the password store with the full fingerprint
echo "Initializing password store with key: CI Test"
pass init "CI Test"

# Create test entries using pass utility

# Create simple test entry
echo -e "password123\nuser:username\nurl:https://google.com" | pass insert -m test/example

# Verify structure
echo "Password store structure:"
find ~/.password-store -type f | sort


# Check if pass can read the passwords itself
echo "Testing if pass can read one of the passwords:"
pass --version || echo "Pass not available"

pass show

# Test the pass import functionality with --no-confirm flag
echo "Running import with --no-confirm flag..."
set -x DEBUG true 
pw import-pass --no-confirm --verbose

# check pw show contains the test entry
echo "Checking if the test entry is available in pwstore"
fish -c "pw show test/example"