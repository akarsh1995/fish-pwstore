#!/usr/bin/env fish
# Special test for pass import functionality in CI environments
# This test is designed to work in GitHub Actions CI environment where
# standard pass import is challenging due to GPG encryption issues

# Change to script directory
set -l script_dir (dirname (status -f))
cd $script_dir/..

# Source the required functions
source ./functions/_pwstore_import_from_pass.fish

# Set CI environment variable if not already set
if not set -q CI
    set -gx CI true
end

# Set debug flags
set -gx DEBUG true
set -gx DEBUG_GPG true

# Output test header
set_color --bold blue
echo "🚀 Starting CI-specific pass import test"
echo "======================================"
set_color normal

# Function to test CI-mode import
function test_ci_pass_import
    set_color cyan
    echo "🧪 Testing pass import with CI fallback mechanisms..."
    set_color normal

    # Use the standard pass store
    set -l pass_dir $HOME/.password-store

    # Make sure we have access to the test pass store
    if not test -d $pass_dir
        set_color red
        echo "❌ Pass directory not found: $pass_dir"
        echo "This test requires a pre-configured ~/.password-store directory"
        set_color normal
        return 1
    end

    # Count files in the pass store
    set -l file_count (find $pass_dir -name "*.gpg" | wc -l | string trim)

    if test $file_count -eq 0
        set_color red
        echo "❌ No .gpg files found in $pass_dir"
        echo "Make sure to set up test files in the pass store"
        set_color normal
        return 1
    end

    set_color green
    echo "Found $file_count password files in $pass_dir"
    set_color normal

    # Mock _pwstore_add to capture import attempts
    function _pwstore_add
        echo "MOCK_ADD: $argv[1]"
        return 0
    end

    # Configure pwstore path to avoid modifying real passwords
    set -g pwstore_path /tmp/ci-pwstore-test

    # Run the import with --no-confirm and --verbose
    echo "Running import with CI fallback mechanisms..."
    _pwstore_import_from_pass $pass_dir --no-confirm --verbose

    # Check return status
    if test $status -ne 0
        set_color red
        echo "❌ Import failed with status $status"
        set_color normal
        return 1
    end

    set_color green
    echo "✅ Import completed successfully"
    set_color normal
    return 0
end

# Setup test environment variable for path utility functions
set -gx PWSTORE_IS_TESTING true

# Run the test
test_ci_pass_import

# Cleanup
echo "Cleaning up temporary files"
rm -rf /tmp/ci-pwstore-test

set_color --bold green
echo "✅ CI-specific pass import test completed"
echo "======================================"
set_color normal
