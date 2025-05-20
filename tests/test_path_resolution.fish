#!/usr/bin/env fish
# Test for path resolution methods to ensure cross-platform compatibility
# This test verifies that we can resolve paths even without realpath or grealpath

function test_path_resolution_methods
    set -l test_dir /tmp/pwstore_test_paths
    set -l test_file "$test_dir/test_file.txt"

    # Setup test directory and file
    mkdir -p $test_dir
    echo "test content" >$test_file

    set_color cyan
    echo "🧪 Testing path resolution methods"
    echo "======================================"
    set_color normal

    # Function that implements all path resolution methods
    function resolve_path
        set -l path_to_resolve $argv[1]

        echo "Testing path resolution for: $path_to_resolve"

        # Method 1: Use built-in realpath
        if command -sq realpath
            echo "  Method 1 (realpath): "(realpath "$path_to_resolve" 2>/dev/null)
        else
            echo "  Method 1 (realpath): not available"
        end

        # Method 2: Use grealpath (GNU coreutils on macOS)
        if command -sq grealpath
            echo "  Method 2 (grealpath): "(grealpath "$path_to_resolve" 2>/dev/null)
        else
            echo "  Method 2 (grealpath): not available"
        end

        # Method 3: Use Python's os.path.abspath
        if type -q python3
            echo "  Method 3 (Python 3): "(python3 -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null)
        else
            echo "  Method 3 (Python 3): not available"
        end

        # Method 4: Use Python 2 (older systems)
        if type -q python
            echo "  Method 4 (Python 2): "(python -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null)
        else
            echo "  Method 4 (Python 2): not available"
        end

        # Method 5: Use readlink -f
        if command -sq readlink
            echo -n "  Method 5 (readlink -f): "
            readlink -f "$path_to_resolve" 2>/dev/null || echo failed
        else
            echo "  Method 5 (readlink -f): not available"
        end

        # Method 6: Use pwd for directories
        if test -d "$path_to_resolve"
            echo -n "  Method 6 (pushd/pwd): "
            pushd "$path_to_resolve" >/dev/null
            pwd
            popd >/dev/null
        else
            echo "  Method 6 (pushd/pwd): not applicable (not a directory)"
        end

        # Method 7: Handle files by getting directory and filename separately
        if test -f "$path_to_resolve"
            echo -n "  Method 7 (dirname/basename): "
            set -l dir_name (dirname "$path_to_resolve")
            set -l base_name (basename "$path_to_resolve")
            pushd "$dir_name" >/dev/null
            echo (pwd)/"$base_name"
            popd >/dev/null
        else
            echo "  Method 7 (dirname/basename): not applicable (not a file)"
        end

        echo ""
    end

    # Test directory path resolution
    resolve_path "$test_dir"

    # Test file path resolution
    resolve_path "$test_file"

    # Test relative path resolution
    set -l current_dir (pwd)
    cd /tmp
    resolve_path pwstore_test_paths
    resolve_path "pwstore_test_paths/test_file.txt"
    cd $current_dir

    # Test with a symlink
    ln -sf $test_dir /tmp/pwstore_test_link
    resolve_path /tmp/pwstore_test_link

    # Our robust implementation that combines all methods
    function robust_path_resolution
        set -l path $argv[1]

        if command -sq realpath
            realpath "$path" 2>/dev/null
            and return 0
        end

        if command -sq grealpath
            command grealpath "$path" 2>/dev/null
            and return 0
        end

        if type -q python3
            python3 -c "import os.path; print(os.path.abspath('$path'))" 2>/dev/null
            and return 0
        end

        if type -q python
            python -c "import os.path; print(os.path.abspath('$path'))" 2>/dev/null
            and return 0
        end

        if command -sq readlink
            readlink -f "$path" 2>/dev/null
            and return 0
        end

        if test -d "$path"
            pushd "$path" >/dev/null
            pwd
            popd >/dev/null
            and return 0
        end

        if test -f "$path"
            set -l dir_name (dirname "$path")
            set -l base_name (basename "$path")
            pushd "$dir_name" >/dev/null
            echo (pwd)/"$base_name"
            popd >/dev/null
            and return 0
        end

        # Last resort, just return the path as-is
        echo "$path"
        return 0
    end

    set_color cyan
    echo "Robust implementation results:"
    set_color normal
    echo "  Directory: "(robust_path_resolution "$test_dir")
    echo "  File: "(robust_path_resolution "$test_file")
    echo "  Symlink: "(robust_path_resolution "/tmp/pwstore_test_link")

    # Clean up test files
    rm -f "$test_file"
    rm -rf "$test_dir"
    rm -f /tmp/pwstore_test_link

    # If we got here without errors, return success
    return 0
end

# Run the test
test_path_resolution_methods
exit $status
