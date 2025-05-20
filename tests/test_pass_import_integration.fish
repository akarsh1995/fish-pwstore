#!/usr/bin/env fish

# ==============================================================================
# SETUP
# ==============================================================================
echo "========== STARTING PASS IMPORT INTEGRATION TEST =========="

# Set environment for pass
export PASSWORD_STORE_DIR=~/.password-store

# Initialize the password store with the full fingerprint
echo "Initializing password store with key: CI Test"
pass init "CI Test"

# ==============================================================================
# SCENARIO 1: CREATING TEST ENTRIES IN PASS
# ==============================================================================
echo "========== CREATING TEST ENTRIES IN PASS =========="

# Create simple test entry
echo -e "password123\nuser:username\nurl:https://google.com" | pass insert -m test/example

# Create entry with multiple fields and special characters
echo -e "secureP@ss!123\nusername: john.doe\nemail: john.doe@example.com\nurl: https://example.com\nnotes: This is a test entry with special characters: !@#\$\%\^\&\*()" | pass insert -m accounts/example-site

# Create entry with nested directories
mkdir -p ~/.password-store/personal/banking
echo -e "bankP@ssw0rd\ncard: 1234-5678-9012-3456\nexpiry: 12/25\npin: 1234\nurl: https://mybank.com" | pass insert -m personal/banking/mybank

# Create entry with empty fields
echo -e "emptypass\nusername:\nemail:" | pass insert -m test/empty-fields

# Create entry with multiline values
echo -e "multilinepass\nnotes: This is a multiline\n note with several\n lines of text\nusername: multiuser" | pass insert -m test/multiline

# ==============================================================================
# SCENARIO 2: VERIFYING PASS SETUP
# ==============================================================================
echo "========== VERIFYING PASS SETUP =========="

# Verify structure
echo "Password store structure:"
find ~/.password-store -type f | sort

# Check if pass can read the passwords itself
echo "Testing if pass can read one of the passwords:"
pass --version || echo "Pass not available"

pass show

# ==============================================================================
# SCENARIO 3: IMPORTING FROM PASS
# ==============================================================================
echo "========== IMPORTING FROM PASS =========="

# Test the pass import functionality with --no-confirm flag
echo "Running import with --no-confirm flag..."
set -x DEBUG true
pw import-pass --no-confirm --verbose

# ==============================================================================
# SCENARIO 4: VERIFYING BASIC IMPORTS
# ==============================================================================
echo "========== VERIFYING BASIC IMPORTS =========="

# Verify that all test entries were imported correctly
echo "Checking if all test entries are available in pwstore..."

echo "Testing simple entry:"
fish -c "pw show test/example"

echo "Testing entry with multiple fields and special characters:"
fish -c "pw show accounts/example-site"

echo "Testing nested directory entry:"
fish -c "pw show personal/banking/mybank"

echo "Testing entry with empty fields:"
fish -c "pw show test/empty-fields"

echo "Testing entry with multiline values:"
fish -c "pw show test/multiline"

# ==============================================================================
# SCENARIO 5: LISTING ENTRIES
# ==============================================================================
echo "========== TESTING LIST FUNCTIONALITY =========="

# Test pw list to verify all entries were imported
echo "Verifying all imported entries with pw list:"
fish -c "pw list"

# ==============================================================================
# SCENARIO 6: FIELD EXTRACTION
# ==============================================================================
echo "========== TESTING FIELD EXTRACTION =========="

# Test field extraction
echo "Testing field extraction capabilities:"
echo "Getting username from test/example:"
fish -c "pw user test/example"

# echo "Getting email from accounts/example-site:"
# fish -c "pw email accounts/example-site"

# echo "Getting card number from banking entry:"
# fish -c "pw card personal/banking/mybank"

# ==============================================================================
# SCENARIO 7: ERROR HANDLING
# ==============================================================================
echo "========== TESTING ERROR HANDLING =========="

# Test error handling with non-existent entry and field
echo "Testing error handling:"
echo "Attempting to show non-existent entry (should fail gracefully):"
fish -c "pw show non/existent/entry" || echo "Failed as expected"

# echo "Attempting to extract non-existent field (should fail gracefully):"
# fish -c "pw show -f nonexistentfield test/example" || echo "Failed as expected"

# ==============================================================================
# TEST SUMMARY
# ==============================================================================
echo "========== TEST SUMMARY =========="
echo "Import test completed successfully!"
echo "===================================================================="
