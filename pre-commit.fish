#!/usr/bin/env fish

# pre-commit.fish
# A script to format all Fish files in the project before committing
# Usage: ./pre-commit.fish
#
# You can also set this up as a git pre-commit hook:
# ln -sf (pwd)/pre-commit.fish .git/hooks/pre-commit

# Set colors for pretty output
set -l success_color (set_color green)
set -l warning_color (set_color yellow)
set -l error_color (set_color red)
set -l reset_color (set_color normal)

# Get list of Fish files that are staged for commit
set -l files_to_format (git diff --cached --name-only --diff-filter=ACM | grep -E '\.fish$')

if test -z "$files_to_format"
    echo "No Fish files to format."
    exit 0
end

echo "🐟 $warning_color Formatting Fish files before commit... $reset_color"
set -l error_count 0

for file in $files_to_format
    if test -f $file
        echo -n "  Formatting $file... "

        # Verify file exists
        if not test -f $file
            echo "$error_color✗ File not found$reset_color"
            set error_count (math $error_count + 1)
            continue
        end

        # Create a backup in case something goes wrong
        cp $file "$file.pre-commit.bak"

        # Format the file
        if fish_indent -w $file 2>/dev/null
            echo "$success_color✓$reset_color"
            git add $file
            rm -f "$file.pre-commit.bak"
        else
            echo "$error_color✗ Error formatting$reset_color"
            mv "$file.pre-commit.bak" $file
            set error_count (math $error_count + 1)
        end
    end
end

# Report status
if test $error_count -eq 0
    echo "$success_color✅ All Fish files formatted successfully.$reset_color"
    exit 0
else
    echo "$error_color❌ Some files could not be formatted. Please check the output above.$reset_color"
    exit 1
end
