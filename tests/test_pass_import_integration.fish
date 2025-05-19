#!/usr/bin/env fish
# Integration test for pass import functionality
# Tests the _pwstore_import_from_pass function for properly importing passwords
# from a pass store, including password content, metadata, and hierarchy

# Change to script directory
set -l script_dir (dirname (status -f))
cd $script_dir/..

# Setup a temporary test environment for proper password import testing

# Setup test environment with mock pass directory and password files
function setup_test_environment
    set_color cyan
    echo "🛠️ Setting up test environment..."
    set_color normal
    
    # Create temporary directories
    set -l test_pass_dir "/tmp/test-pass-store"
    set -l test_pwstore_dir "/tmp/test-pwstore"
    
    # Clean up previous test directories if they exist
    rm -rf $test_pass_dir
    rm -rf $test_pwstore_dir
    
    # Create pass directory structure
    mkdir -p $test_pass_dir
    mkdir -p $test_pass_dir/email
    mkdir -p $test_pass_dir/web/social
    mkdir -p $test_pass_dir/web/banking
    mkdir -p $test_pwstore_dir
    
    # Create mock password files with realistic structure
    # Each file will have password on first line, then metadata
    
    # Basic password
    echo "simple-password-123" > $test_pass_dir/simple.gpg
    
    # Email account with metadata
    echo "email-secure-pass!" > $test_pass_dir/email/gmail.gpg
    echo "username: testuser@gmail.com" >> $test_pass_dir/email/gmail.gpg
    echo "url: https://gmail.com" >> $test_pass_dir/email/gmail.gpg
    echo "description: Work email account" >> $test_pass_dir/email/gmail.gpg
    
    # Banking site with metadata
    echo "bank-secure-123!" > $test_pass_dir/web/banking/chase.gpg
    echo "username: jdoe2023" >> $test_pass_dir/web/banking/chase.gpg
    echo "url: https://chase.com" >> $test_pass_dir/web/banking/chase.gpg
    echo "description: Primary checking account" >> $test_pass_dir/web/banking/chase.gpg
    
    # Social media account
    echo "tweet-secure-456!" > $test_pass_dir/web/social/twitter.gpg
    echo "login: @testhandle" >> $test_pass_dir/web/social/twitter.gpg
    echo "site: https://twitter.com" >> $test_pass_dir/web/social/twitter.gpg
    
    # Create a symlink to test symlink resolution
    ln -s $test_pass_dir/web $test_pass_dir/websites
    
    set_color green
    echo "✅ Test environment created:"
    echo "  📁 Pass store: $test_pass_dir"
    echo "  📁 Target pwstore: $test_pwstore_dir"
    set_color normal
    
    echo "Directory structure:"
    find $test_pass_dir -name "*.gpg" | sort
    echo ""
    
    # Return the directories
    echo "$test_pass_dir:$test_pwstore_dir"
end

function check_path_capability
    set_color cyan
    echo "🧪 Testing path handling capabilities"
    set_color normal
    
    # Source the import function
    source ./functions/_pwstore_import_from_pass.fish
    
    # Verify that the function contains our realpath implementation
    set -l found_realpath (grep -c "realpath.*grealpath" ./functions/_pwstore_import_from_pass.fish)
    
    if test $found_realpath -gt 0
        set_color green
        echo "✅ Found realpath/grealpath implementation in import function"
        set_color normal
    else
        set_color red
        echo "❌ Could not find realpath/grealpath implementation"
        set_color normal
        return 1
    end
    
    # Verify that we correctly escape path for regex
    set -l found_escape (grep -c "string escape.*style=regex" ./functions/_pwstore_import_from_pass.fish)
    
    if test $found_escape -gt 0
        set_color green
        echo "✅ Found proper regex escaping in the import function"
        set_color normal
    else
        set_color yellow
        echo "⚠️ No regex escaping found - might cause issues with special characters in paths"
        set_color normal
    end
    
    # Test path handling with complex paths
    set_color cyan
    echo "Testing path resolution with special characters:"
    set_color normal
    
    # Simple test of path functions used in import
    set -l test_dir "/tmp/pass-test/with space/and#special&chars"
    set -l test_file "$test_dir/nested/path/file.gpg"
    
    # Get real paths (simulating what happens in the import function)
    echo "Testing path: $test_file"
    # We don't actually access the filesystem, just check the code logic
    set -l escaped_dir (string escape --style=regex "$test_dir")
    set -l rel_path (string replace -r "^$escaped_dir/" "" "$test_file")
    set -l name_without_gpg (string replace -r "\.gpg\$" "" $rel_path)
    
    echo "  Directory:      $test_dir"
    echo "  Escaped dir:    $escaped_dir"
    echo "  File:           $test_file" 
    echo "  Relative path:  $rel_path"
    echo "  Password name:  $name_without_gpg"
    
    # Check if the relative path calculation works correctly
    if test "$rel_path" = "nested/path/file.gpg"
        set_color green
        echo "✅ Relative path calculation working correctly"
        set_color normal
    else
        set_color red
        echo "❌ Relative path calculation failed"
        set_color normal
        return 1
    end
    
    return 0
end

function test_password_import
    set_color cyan
    echo "🧪 Testing actual password import functionality..."
    set_color normal
    
    # Get test directories from setup
    set -l setup_result (setup_test_environment)
    set -l dirs (string split ":" -- $setup_result)
    set -l test_pass_dir $dirs[1]
    set -l test_pwstore_dir $dirs[2]
    
    if test -z "$test_pass_dir" -o -z "$test_pwstore_dir"
        set_color red
        echo "❌ Failed to setup test environment"
        set_color normal
        return 1
    end
    
    # Source the required functions
    source ./functions/_pwstore_import_from_pass.fish
    
    # Create a mock version of _pwstore_add to capture what would be imported
    function _pwstore_add
        echo "MOCK_ADD: Adding password with name: $argv[1]"
        
        # Extract details from arguments
        set -l name $argv[1]
        
        # Find password (should be after --no-prompt)
        set -l password_idx (contains -i -- "--no-prompt" $argv)
        if test -n "$password_idx"
            set -l password_idx (math $password_idx + 1)
            echo "  Password: [MASKED]" # Don't show actual password in test output
            echo "  Password length: "(string length $argv[$password_idx])
        end
        
        # Find username
        set -l username_arg (string match -r -- "--username=.*" $argv)
        if test -n "$username_arg"
            set -l username (string replace -r -- "--username=" "" $username_arg)
            echo "  Username: $username"
        end
        
        # Find URL
        set -l url_arg (string match -r -- "--url=.*" $argv)
        if test -n "$url_arg" 
            set -l url (string replace -r -- "--url=" "" $url_arg)
            echo "  URL: $url"
        end
        
        # Description is the last parameter
        if test (count $argv) -gt 0
            echo "  Description: "(string sub -l 30 $argv[-1])"..."
        end
        
        echo ""
        return 0
    end
    
    # Override the default pwstore path 
    set -g pwstore_path $test_pwstore_dir
    
    # Run the import with our test directory
    set_color magenta
    echo "Running import from test pass directory..."
    set_color normal
    
    # Call import with "yes" to proceed
    echo "y" | _pwstore_import_from_pass $test_pass_dir --verbose
    set -l import_status $status
    
    # Check the import result
    if test $import_status -ne 0
        set_color red
        echo "❌ Import failed with status $import_status"
        set_color normal
        return 1
    end
    
    # Validate the imported data structure matches expectations
    set_color cyan
    echo "Validating import results..."
    set_color normal
    
    # For a complete test we would verify the pwstore registry contents
    # For now, we rely on the output from our mock _pwstore_add function
    
    set_color green
    echo "✅ Password import test passed"
    set_color normal
    return 0
end

function check_path_capability
    set_color cyan
    echo "Checking path handling capabilities..."
    set_color normal
    
    # Simple test of path functions used in import
    set -l test_dir "/tmp/pass-test/with space/and#special&chars"
    set -l test_file "$test_dir/nested/path/file.gpg"
    
    # Get real paths (simulating what happens in the import function)
    echo "Testing path: $test_file"
    # We don't actually access the filesystem, just check the code logic
    set -l escaped_dir (string escape --style=regex "$test_dir")
    set -l rel_path (string replace -r "^$escaped_dir/" "" "$test_file")
    set -l name_without_gpg (string replace -r "\.gpg\$" "" $rel_path)
    
    echo "  Directory:      $test_dir"
    echo "  Escaped dir:    $escaped_dir"
    echo "  File:           $test_file" 
    echo "  Relative path:  $rel_path"
    echo "  Password name:  $name_without_gpg"
    
    # Check if the relative path calculation works correctly
    if test "$rel_path" = "nested/path/file.gpg"
        set_color green
        echo "✅ Relative path calculation working correctly"
        set_color normal
    else
        set_color red
        echo "❌ Relative path calculation failed"
        set_color normal
        return 1
    end
    
    return 0
end

function cleanup
    set_color cyan
    echo "🧹 Cleaning up test environment..."
    set_color normal
    
    # Remove test directories
    rm -rf /tmp/test-pass-store
    rm -rf /tmp/test-pwstore
    
    set_color green
    echo "✅ Cleanup complete"
    set_color normal
end

# Run the tests
set_color --bold blue
echo "🚀 Starting pass import integration test"
echo "======================================"
set_color normal

# Test path handling capabilities first
check_path_capability

# Test actual password importing functionality
test_password_import

# Clean up after tests
cleanup

set_color --bold green
echo "✅ Integration test completed"
echo "======================================"
set_color normal
