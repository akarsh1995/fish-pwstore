#!/usr/bin/env fish

# Script to run fish_indent on all Fish files in the project
# Usage:
#   ./run_fish_indent.fish          # Format all files
#   ./run_fish_indent.fish --check  # Only check formatting without changes
#   ./run_fish_indent.fish --git    # Only format staged git files

set -l project_dir (dirname (status -f))
cd $project_dir

set -l check_only 0
set -l git_only 0

# Parse arguments
for arg in $argv
    switch $arg
        case --check
            set check_only 1
        case --git
            set git_only 1
        case --help -h
            echo "Usage: ./run_fish_indent.fish [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --check    Check formatting without making changes"
            echo "  --git      Only format git-staged files"
            echo "  --help,-h  Show this help message"
            exit 0
    end
end

# Set header message based on mode
if test $check_only -eq 1
    set_color --bold blue
    echo "🔍 Checking Fish file formatting in $project_dir"
    set_color normal
else if test $git_only -eq 1
    set_color --bold blue
    echo "🔍 Formatting git-staged Fish files in $project_dir"
    set_color normal
else
    set_color --bold blue
    echo "✏️ Formatting all Fish files in $project_dir"
    set_color normal
end

echo "======================================"

# Find Fish files based on mode
set -l fish_files
if test $git_only -eq 1
    # Only get git staged files
    set fish_files (git diff --cached --name-only --diff-filter=ACM | grep -E '\.fish$' | sort)
    if test (count $fish_files) -eq 0
        set_color yellow
        echo "No git-staged Fish files found."
        set_color normal
        exit 0
    end
else
    # Get all Fish files
    set fish_files (find . -type f -name "*.fish" | sort)
end

set -l count (count $fish_files)

echo "Found $count Fish files to process"
echo ""

# Process each file
set -l success_count 0
set -l malformatted_count 0
set -l malformatted_files

for file in $fish_files
    # Check formatting
    if test $check_only -eq 1
        echo -n "Checking $file... "
        if fish_indent -c $file 2>/dev/null
            set_color green
            echo "✓ Correct"
            set_color normal
            set success_count (math $success_count + 1)
        else
            set_color red
            echo "✗ Needs formatting"
            set_color normal
            set malformatted_count (math $malformatted_count + 1)
            set -a malformatted_files $file
        end
    else
        # Format the file
        echo -n "Formatting $file... "
        # Create a backup file
        cp $file "$file.bak"

        # Format the file in place
        if fish_indent -w $file 2>/dev/null
            set_color green
            echo "✓ Done"
            set_color normal
            set success_count (math $success_count + 1)
            rm "$file.bak"
        else
            set_color red
            echo "✗ Error"
            set_color normal
            mv "$file.bak" $file
        end
    end
end

echo ""

# Show summary based on mode
if test $check_only -eq 1
    if test $malformatted_count -eq 0
        set_color green
        echo "🎉 All $count files are correctly formatted!"
        set_color normal
        exit 0
    else
        set_color yellow
        echo "⚠️ Found $malformatted_count files that need formatting:"
        set_color normal

        for file in $malformatted_files
            echo "   - $file"
        end

        set_color --bold
        echo ""
        echo "Run './run_fish_indent.fish' to format these files."
        set_color normal
        exit 1
    end
else
    set_color green
    echo "✅ Successfully processed $success_count out of $count files"
    set_color normal
end
