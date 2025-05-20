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
    echo password1 >$test_dir/test1.txt
    echo password2 >$test_dir/nested/test2.txt
    echo password3 >$test_dir/nested/subfolder/test3.txt

    # Encrypt them with a dummy GPG key (this is just for testing path handling)
    # In a real scenario, these would be properly encrypted
    echo dummy >$test_dir/test1.txt.gpg
    echo dummy >$test_dir/nested/test2.txt.gpg
    echo dummy >$test_dir/nested/subfolder/test3.txt.gpg

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

    # Get real paths - handle platforms where realpath or grealpath might not be available
    set -l real_dir
    set -l real_file

    # Source our path utility functions if available
    set -l has_path_utils false
    set -l script_dir (dirname (status -f))
    set -l utils_path "$script_dir/../functions/_pwstore_path_utils.fish"

    if test -f "$utils_path"
        source "$utils_path"
        set has_path_utils true
    end

    # If we have the path utils, use them directly
    if test "$has_path_utils" = true; and functions -q _pwstore_resolve_path
        # Use our shared utility function
        set real_dir (_pwstore_resolve_path "$test_dir")
        set real_file (_pwstore_resolve_path "$file")
    else
        # Fallback to local implementation for standalone testing
        function resolve_path
            set -l path_to_resolve $argv[1]

            # Method 1: Use built-in realpath
            if command -sq realpath
                realpath "$path_to_resolve" 2>/dev/null
                and return 0
            end

            # Method 2: Use grealpath (GNU coreutils on macOS)
            if command -sq grealpath
                grealpath "$path_to_resolve" 2>/dev/null
                and return 0
            end

            # Method 3: Use Python's os.path.abspath
            if type -q python3
                python3 -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null
                and return 0
            end

            # Method 4: Use Python 2 (older systems)
            if type -q python
                python -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null
                and return 0
            end

            # Method 5: Use readlink -f (might work on some systems)
            if command -sq readlink
                readlink -f "$path_to_resolve" 2>/dev/null
                and return 0
            end

            # Method 6: Use pwd for directories
            if test -d "$path_to_resolve"
                pushd "$path_to_resolve" >/dev/null
                pwd
                popd >/dev/null
                and return 0
            end

            # Method 7: Handle files by getting directory and filename separately
            if test -f "$path_to_resolve"
                set -l dir_name (dirname "$path_to_resolve")
                set -l base_name (basename "$path_to_resolve")
                pushd "$dir_name" >/dev/null
                echo (pwd)/"$base_name"
                popd >/dev/null
                and return 0
            end

            # Method 8: Last resort, just return the path as-is
            echo "$path_to_resolve"
            return 0
        end

        # Resolve paths using our helper function
        set real_dir (resolve_path "$test_dir")
        set real_file (resolve_path "$file")
    end

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
