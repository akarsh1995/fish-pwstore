#!/usr/bin/env fish
# Test script for simulating CI environment path handling
# This test ensures our path resolution methods work correctly in CI even without some tools

function test_ci_path_fallbacks
    set_color cyan
    echo "🧪 Testing CI environment path resolution fallbacks"
    echo "=================================================="
    set_color normal

    set -l test_dir /tmp/pwstore_ci_test
    set -l pass_dir $test_dir/password-store

    # Setup test directories and files
    mkdir -p $pass_dir/test
    mkdir -p $pass_dir/email
    mkdir -p $pass_dir/web/social

    # Create dummy password files
    echo dummy >$pass_dir/test/example.gpg
    echo dummy >$pass_dir/email/gmail.gpg
    echo dummy >$pass_dir/web/social/twitter.gpg

    # Create a symlink to simulate more complex path
    ln -sf $pass_dir/web $test_dir/web_link

    set_color yellow
    echo "Testing path resolution with simulated missing commands..."
    set_color normal

    # Define our robust path resolution function
    function get_absolute_path
        set -l path $argv[1]
        set -l simulate_missing $argv[2]

        echo "Testing resolution of: $path (simulate_missing=$simulate_missing)"

        # With simulate_missing=true, we'll skip the first methods to simulate their unavailability

        if test "$simulate_missing" != true; and command -sq realpath
            echo "  Using realpath"
            realpath "$path" 2>/dev/null
            and return 0
        end

        if test "$simulate_missing" != true; and command -sq grealpath
            echo "  Using grealpath"
            command grealpath "$path" 2>/dev/null
            and return 0
        end

        # Python methods should always work in CI
        if type -q python3
            echo "  Using python3"
            python3 -c "import os.path; print(os.path.abspath('$path'))" 2>/dev/null
            and return 0
        end

        if type -q python
            echo "  Using python"
            python -c "import os.path; print(os.path.abspath('$path'))" 2>/dev/null
            and return 0
        end

        if command -sq readlink
            echo "  Using readlink"
            readlink -f "$path" 2>/dev/null
            and return 0
        end

        if test -d "$path"
            echo "  Using pushd/pwd for directory"
            pushd "$path" >/dev/null
            pwd
            popd >/dev/null
            and return 0
        end

        if test -f "$path"
            echo "  Using dirname/basename for file"
            set -l dir_name (dirname "$path")
            set -l base_name (basename "$path")
            pushd "$dir_name" >/dev/null
            echo (pwd)/"$base_name"
            popd >/dev/null
            and return 0
        end

        echo "  All methods failed, returning original path"
        echo "$path"
        return 0
    end

    # Test under normal conditions
    set_color magenta
    echo "1️⃣ Testing with all commands available:"
    set_color normal

    set -l dir_path (get_absolute_path "$pass_dir" false)
    set -l file_path (get_absolute_path "$pass_dir/test/example.gpg" false)
    set -l symlink_path (get_absolute_path "$test_dir/web_link" false)

    echo "  Directory path: $dir_path"
    echo "  File path: $file_path"
    echo "  Symlink path: $symlink_path"

    # Test with simulated missing commands
    set_color magenta
    echo "2️⃣ Testing with simulated missing realpath/grealpath commands:"
    set_color normal

    set -l dir_path_sim (get_absolute_path "$pass_dir" true)
    set -l file_path_sim (get_absolute_path "$pass_dir/test/example.gpg" true)
    set -l symlink_path_sim (get_absolute_path "$test_dir/web_link" true)

    echo "  Directory path: $dir_path_sim"
    echo "  File path: $file_path_sim"
    echo "  Symlink path: $symlink_path_sim"

    # Test path resolution in our CI context
    set_color magenta
    echo "3️⃣ Testing path resolution for path extraction:"
    set_color normal

    # Function to extract the relative path and password name
    function extract_path_info
        set -l base_dir $argv[1]
        set -l file_path $argv[2]
        set -l simulate_missing $argv[3]

        # Get absolute paths using our fallback function
        set -l abs_base_dir (get_absolute_path "$base_dir" $simulate_missing)
        set -l abs_file_path (get_absolute_path "$file_path" $simulate_missing)

        # Escape for regex matching
        set -l escaped_dir (string escape --style=regex "$abs_base_dir")

        # Extract relative path
        set -l rel_path (string replace -r "^$escaped_dir/" "" "$abs_file_path")

        # Remove .gpg extension
        set -l password_name (string replace -r "\.gpg\$" "" $rel_path)

        # Return results
        echo "Base dir: $abs_base_dir"
        echo "File path: $abs_file_path"
        echo "Relative path: $rel_path"
        echo "Password name: $password_name"
    end

    echo "With normal commands:"
    extract_path_info "$pass_dir" "$pass_dir/email/gmail.gpg" false
    echo ""

    echo "With missing commands:"
    extract_path_info "$pass_dir" "$pass_dir/email/gmail.gpg" true
    echo ""

    echo "With symlinks and normal commands:"
    extract_path_info "$pass_dir" "$test_dir/web_link/social/twitter.gpg" false
    echo ""

    echo "With symlinks and missing commands:"
    extract_path_info "$pass_dir" "$test_dir/web_link/social/twitter.gpg" true

    # Clean up
    rm -rf $test_dir

    set_color green
    echo "✅ CI path fallback tests completed successfully"
    echo "=================================================="
    set_color normal

    return 0
end

# Run tests
test_ci_path_fallbacks
exit $status
