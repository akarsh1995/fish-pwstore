#!/usr/bin/env fish
# Advanced test for path resolution to handle edge cases
# Tests for spaces, special characters, deeply nested paths, symlinks, etc.

function test_advanced_path_resolution
    set_color --bold blue
    echo "🔬 Advanced Path Resolution Testing"
    echo "======================================"
    set_color normal

    # Create test directory with challenging path structure
    set -l test_base_dir /tmp/pwstore_path_test

    # Clean up previous test directory
    if test -d "$test_base_dir"
        rm -rf "$test_base_dir"
    end

    # Create directories with challenging names
    mkdir -p "$test_base_dir/normal/path"
    mkdir -p "$test_base_dir/path with spaces/nested"
    mkdir -p "$test_base_dir/special_chars-!@#\$%^&/test"
    mkdir -p "$test_base_dir/deeply/nested/paths/for/testing/resolution"

    # Create test files
    echo test1 >"$test_base_dir/normal/path/file.txt"
    echo test2 >"$test_base_dir/path with spaces/nested/file with spaces.txt"
    echo test3 >"$test_base_dir/special_chars-!@#\$%^&/test/special!file.txt"
    echo test4 >"$test_base_dir/deeply/nested/paths/for/testing/resolution/deep_file.txt"

    # Create symlinks
    ln -sf "$test_base_dir/normal/path" "$test_base_dir/link_to_normal"
    ln -sf "$test_base_dir/path with spaces" "$test_base_dir/link_to_spaces"
    ln -sf "$test_base_dir/deeply/nested/paths" "$test_base_dir/link_to_deep"

    # Create nested symlinks (symlinks to symlinks)
    ln -sf "$test_base_dir/link_to_normal" "$test_base_dir/nested_link"

    # Advanced cases: relative paths with ./ and ../
    mkdir -p "$test_base_dir/relative_test/a/b"
    echo test5 >"$test_base_dir/relative_test/a/b/file.txt"
    pushd "$test_base_dir/relative_test" >/dev/null
    ln -sf "./a/b" "./link_to_ab"
    ln -sf "../relative_test/a" "./link_to_a"
    popd >/dev/null

    # Function that implements our robust path resolution
    # This should match the implementation in _pwstore_import_from_pass.fish
    function resolve_absolute_path
        set -l path_to_resolve $argv[1]

        # Method 1: Try with built-in realpath command
        if command -sq realpath
            realpath "$path_to_resolve" 2>/dev/null
            and return 0
        end

        # Method 2: Try with grealpath (GNU coreutils on macOS)
        if command -sq grealpath
            command grealpath "$path_to_resolve" 2>/dev/null
            and return 0
        end

        # Method 3: Use Python's os.path.abspath if available
        if type -q python3
            python3 -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null
            and return 0
        end

        # Method 4: Try Python 2 if Python 3 isn't available
        if type -q python
            python -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null
            and return 0
        end

        # Method 5: Try readlink -f (works on some systems)
        if command -sq readlink
            readlink -f "$path_to_resolve" 2>/dev/null
            and return 0
        end

        # Method 6: For directories, use pwd
        if test -d "$path_to_resolve"
            pushd "$path_to_resolve" >/dev/null
            pwd
            popd >/dev/null
            and return 0
        end

        # Method 7: For files, get the absolute path of the directory, then append the filename
        if test -f "$path_to_resolve"
            set -l dir_name (dirname "$path_to_resolve")
            set -l base_name (basename "$path_to_resolve")
            pushd "$dir_name" >/dev/null
            echo (pwd)/"$base_name"
            popd >/dev/null
            and return 0
        end

        # Method 8: Last resort, return the path unchanged
        echo "$path_to_resolve"
        return 0
    end

    # Function to test path extraction (relative path within a base dir)
    function test_path_extraction
        set -l base_dir $argv[1]
        set -l file_path $argv[2]
        set -l description $argv[3]

        echo "Test: $description"
        echo "  Base dir: $base_dir"
        echo "  File path: $file_path"

        # Resolve to absolute paths
        set -l real_base_dir (resolve_absolute_path "$base_dir")
        set -l real_file_path (resolve_absolute_path "$file_path")

        # Extract relative path
        set -l escaped_dir (string escape --style=regex "$real_base_dir")
        set -l rel_path (string replace -r "^$escaped_dir/" "" "$real_file_path")

        echo "  Resolved base: $real_base_dir"
        echo "  Resolved file: $real_file_path"
        echo "  Extracted relative path: "(set_color green)"$rel_path"(set_color normal)
        echo ""
    end

    # Run tests for each case
    set_color magenta
    echo "1️⃣ Normal paths"
    set_color normal
    test_path_extraction "$test_base_dir" "$test_base_dir/normal/path/file.txt" "Simple nested path"

    set_color magenta
    echo "2️⃣ Paths with spaces"
    set_color normal
    test_path_extraction "$test_base_dir" "$test_base_dir/path with spaces/nested/file with spaces.txt" "Path with spaces"

    set_color magenta
    echo "3️⃣ Paths with special characters"
    set_color normal
    test_path_extraction "$test_base_dir" "$test_base_dir/special_chars-!@#\$%^&/test/special!file.txt" "Path with special chars"

    set_color magenta
    echo "4️⃣ Deeply nested paths"
    set_color normal
    test_path_extraction "$test_base_dir" "$test_base_dir/deeply/nested/paths/for/testing/resolution/deep_file.txt" "Deeply nested path"

    set_color magenta
    echo "5️⃣ Symlinked paths"
    set_color normal
    test_path_extraction "$test_base_dir" "$test_base_dir/link_to_normal/file.txt" "Simple symlink"
    test_path_extraction "$test_base_dir" "$test_base_dir/link_to_spaces/nested/file with spaces.txt" "Symlink with spaces"
    test_path_extraction "$test_base_dir" "$test_base_dir/link_to_deep/for/testing/resolution/deep_file.txt" "Symlink to deep path"

    set_color magenta
    echo "6️⃣ Nested symlinks"
    set_color normal
    test_path_extraction "$test_base_dir" "$test_base_dir/nested_link/file.txt" "Nested symlink"

    set_color magenta
    echo "7️⃣ Relative paths"
    set_color normal
    pushd "$test_base_dir/relative_test" >/dev/null
    test_path_extraction "." "./a/b/file.txt" "Simple relative path with ./"
    test_path_extraction "." "./link_to_ab/file.txt" "Relative symlink with ./"
    test_path_extraction "." "./link_to_a/b/file.txt" "Relative path with ../"
    popd >/dev/null

    set_color magenta
    echo "8️⃣ Testing relative path extraction between directories"
    set_color normal
    test_path_extraction "$test_base_dir" "$test_base_dir/relative_test/a/b/file.txt" "Parent to nested child"
    test_path_extraction "$test_base_dir/relative_test" "$test_base_dir/relative_test/a/b/file.txt" "Parent to direct child"

    # Clean up
    rm -rf "$test_base_dir"

    set_color --bold green
    echo "✅ Advanced path resolution tests completed"
    echo "======================================"
    set_color normal

    return 0
end

# Run the test
test_advanced_path_resolution
exit $status
