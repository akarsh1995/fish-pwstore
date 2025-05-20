# Helper functions for consistent path resolution across all fish-pwstore components
# This helps ensure cross-platform compatibility and handles edge cases

# Function to get absolute path of a file or directory
# Works across platforms with fallbacks for systems without realpath/grealpath
function _pwstore_resolve_path --description "Get absolute path with robust fallback methods"
    set -l path_to_resolve $argv[1]

    if test -z "$path_to_resolve"
        return 1
    end

    # Method 1: Use built-in realpath if available
    if command -sq realpath
        realpath "$path_to_resolve" 2>/dev/null
        and return 0
    end

    # Method 2: Use grealpath (GNU coreutils on macOS) if available
    if command -sq grealpath
        command grealpath "$path_to_resolve" 2>/dev/null
        and return 0
    end

    # Method 3: Use Python's os.path.abspath if available
    if type -q python3
        python3 -c "import os.path; print(os.path.abspath('$path_to_resolve'))" 2>/dev/null
        and return 0
    end

    # Method 4: Use Python 2 if Python 3 isn't available
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

# Function to extract a relative path from a base directory
# This is useful for pass import and similar operations
function _pwstore_get_relative_path --description "Get path relative to a base directory"
    set -l base_dir $argv[1]
    set -l target_path $argv[2]

    if test -z "$base_dir"; or test -z "$target_path"
        return 1
    end

    # Get absolute paths first
    set -l abs_base_dir (_pwstore_resolve_path "$base_dir")
    set -l abs_target_path (_pwstore_resolve_path "$target_path")

    # Escape special characters in the directory path for regex
    set -l escaped_dir (string escape --style=regex "$abs_base_dir")

    # Extract relative path using regex replacement
    string replace -r "^$escaped_dir/" "" "$abs_target_path"
    return $status
end
