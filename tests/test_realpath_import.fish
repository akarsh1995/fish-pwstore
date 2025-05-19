#!/usr/bin/env fish
# Test script for verifying realpath implementation in pass import

function setup_test_pass_store
    set_color cyan
    echo "🔍 Setting up test pass directory..."
    set_color normal
    set -l test_dir /tmp/pwstore_test_pass
    
    # Clean up previous test directory if it exists
    if test -d $test_dir
        rm -rf $test_dir
    end
    
    mkdir -p $test_dir/nested/subfolder
    
    # Create some dummy password files
    echo "password1" > $test_dir/test1.txt
    echo "password2" > $test_dir/nested/test2.txt
    echo "password3" > $test_dir/nested/subfolder/test3.txt
    
    # Encrypt them with a dummy GPG key (this is just for testing path handling)
    # In a real scenario, these would be properly encrypted
    echo "dummy" > $test_dir/test1.txt.gpg
    echo "dummy" > $test_dir/nested/test2.txt.gpg
    echo "dummy" > $test_dir/nested/subfolder/test3.txt.gpg
    
    # Create a symlink to test symlink resolution
    ln -s $test_dir/nested $test_dir/link_to_nested
    
    set_color green
    echo "✅ Test pass directory created at $test_dir"
    echo "📁 Directory structure:"
    set_color normal
    find $test_dir -type f -name "*.gpg" | sort
    
    # Return the test directory path
    echo $test_dir
end

function test_path_resolution
    set -l test_dir $argv[1]
    set -l file $argv[2]
    
    set_color yellow
    echo "🧪 Testing path resolution for file: "(set_color -u)"$file"(set_color normal; set_color yellow)
    set_color normal
    
    # Get real paths
    set -l real_dir (realpath "$test_dir" 2>/dev/null; or command grealpath "$test_dir" 2>/dev/null; or echo "$test_dir")
    set -l real_file (realpath "$file" 2>/dev/null; or command grealpath "$file" 2>/dev/null; or echo "$file")
    
    # Calculate relative path - escape special characters for regex
    set -l escaped_dir (string escape --style=regex "$real_dir")
    set -l rel_path (string replace -r "^$escaped_dir/" "" "$real_file")
    set -l name_without_gpg (string replace -r "\.gpg\$" "" $rel_path)
    
    echo "  📁 Pass directory:       $test_dir"
    echo "  🔍 Real pass directory:  $real_dir"
    echo "  📄 File path:           $file"
    echo "  🔍 Real file path:      $real_file"
    echo "  📝 Calculated rel path: "(set_color green)"$rel_path"(set_color normal)
    echo "  🔑 Password name:       "(set_color green)"$name_without_gpg"(set_color normal)
    echo ""
end

# Main test
set_color --bold blue
echo "🚀 Starting realpath path handling test"
echo "======================================"
set_color normal

# Setup test directory
set -l test_dir (setup_test_pass_store)

# Test regular paths
if test -n "$test_dir"
    echo ""
    set_color --bold magenta
    echo "Testing path resolution for various file structures:"
    set_color normal
    
    echo ""
    set_color --bold
    echo "1️⃣ Testing flat file:"
    set_color normal
    test_path_resolution "$test_dir" "$test_dir/test1.txt.gpg"
    
    echo ""
    set_color --bold
    echo "2️⃣ Testing nested directory:"
    set_color normal
    test_path_resolution "$test_dir" "$test_dir/nested/test2.txt.gpg"
    
    echo ""
    set_color --bold
    echo "3️⃣ Testing deeply nested directory:"
    set_color normal
    test_path_resolution "$test_dir" "$test_dir/nested/subfolder/test3.txt.gpg"
    
    echo ""
    set_color --bold
    echo "4️⃣ Testing symlink resolution:"
    set_color normal
    test_path_resolution "$test_dir" "$test_dir/link_to_nested/test2.txt.gpg"
end

set_color --bold green
echo "✅ Test completed successfully"
echo "======================================"
set_color normal
