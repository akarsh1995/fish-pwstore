#!/usr/bin/env fish
# Test script for verifying GPG environment setup

function test_gpg_environment
    set_color cyan
    echo "🔍 Testing GPG environment setup..."
    set_color normal

    # Check for GPG installation
    if not command -q gpg
        set_color red
        echo "❌ GPG is not installed or not in PATH"
        set_color normal
        return 1
    end

    # Show GPG version
    echo "GPG version: "(gpg --version | head -n 1)

    # Check for available keys
    set -l key_count (gpg --list-keys | grep -c "^pub")

    if test $key_count -eq 0
        set_color red
        echo "❌ No GPG keys found"
        set_color normal
        return 1
    end

    echo "Found $key_count GPG key(s)"

    # Check pwstore environment variables
    echo "pwstore_path: $pwstore_path"
    echo "pwstore_gpg_recipient: $pwstore_gpg_recipient"

    if test -z "$pwstore_gpg_recipient"
        set_color red
        echo "❌ pwstore_gpg_recipient is not set"
        set_color normal
        return 1
    end

    # Check that the recipient exists in the keyring
    if not gpg --list-keys "$pwstore_gpg_recipient" >/dev/null 2>&1
        set_color red
        echo "❌ The specified GPG recipient '$pwstore_gpg_recipient' was not found in the keyring"
        set_color normal
        return 1
    end

    # Check that we can encrypt and decrypt a test file
    set -l test_file /tmp/pwstore_gpg_test
    echo "test content" >$test_file

    if not gpg --encrypt --recipient "$pwstore_gpg_recipient" -o "$test_file.gpg" "$test_file" 2>/dev/null
        set_color red
        echo "❌ Failed to encrypt test file"
        set_color normal
        rm -f $test_file
        return 1
    end

    rm -f $test_file
    if not gpg --decrypt -o "$test_file" "$test_file.gpg" 2>/dev/null
        set_color red
        echo "❌ Failed to decrypt test file"
        set_color normal
        rm -f $test_file $test_file.gpg
        return 1
    end

    set -l decrypted (cat $test_file)
    rm -f $test_file $test_file.gpg

    if test "$decrypted" != "test content"
        set_color red
        echo "❌ Decrypted content does not match original"
        set_color normal
        return 1
    end

    set_color green
    echo "✅ GPG environment is properly configured"
    set_color normal
    return 0
end

# Run test
test_gpg_environment
