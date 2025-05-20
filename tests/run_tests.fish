#!/usr/bin/env fish
# Test runner for fish-pwstore
# Runs all tests in the tests directory

# Change to script directory
set -l script_dir (dirname (status -f))
cd $script_dir

# Get all test files
set -l test_files (find . -name "test_*.fish" -type f | sort)

set -l pass_count 0
set -l fail_count 0
set -l total_count 0

set_color --bold blue
echo "🧪 Running fish-pwstore tests"
echo "=================================="
set_color normal
echo "Found "(count $test_files)" test files"
echo ""

# Run each test
for test_file in $test_files
    set total_count (math $total_count + 1)

    set_color --bold yellow
    echo "🔍 Running test: $test_file"
    set_color normal

    # Run the test
    $test_file

    # Check result
    if test $status -eq 0
        set pass_count (math $pass_count + 1)
        set_color green
        echo "✅ Test passed: $test_file"
    else
        set fail_count (math $fail_count + 1)
        set_color red
        echo "❌ Test failed: $test_file"
    end

    set_color normal
    echo ----------------------------------
    echo ""
end

# Show summary
echo ""
set_color --bold blue
echo "Test Summary"
echo "=================================="
set_color --bold
echo "Total tests: $total_count"

if test $pass_count -eq $total_count
    set_color --bold green
    echo "All tests passed! ✅"
else
    set_color --bold green
    echo "Passed: $pass_count"
    set_color --bold red
    echo "Failed: $fail_count"
    if test $fail_count -gt 0
        echo "❌ Some tests failed"
    end
end

set_color normal
