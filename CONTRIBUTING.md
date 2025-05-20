# Contributing to fish-pwstore

Thank you for your interest in contributing to fish-pwstore! Here's how you can help:

## Bug Reports and Feature Requests

- Use the GitHub issue tracker to report bugs or request features
- Check existing issues before opening a new one
- Provide detailed information when reporting bugs (OS, Fish shell version, etc.)

## Pull Requests

1. Fork the repository
2. Create a new branch for your changes
3. Add tests for new features
4. Format your code using `fish_indent` (see Code Formatting section below)
5. Run the test suite to make sure everything passes
6. Submit a pull request

## Code Style and Formatting

All Fish files must be properly formatted using `fish_indent`. We have provided scripts to help with this:

1. Format all Fish files in the repository:
   ```fish
   ./run_fish_indent.fish
   ```

2. Check formatting without making changes:
   ```fish
   ./run_fish_indent.fish --check
   ```

3. Install the pre-commit hook to automatically format staged files:
   ```fish
   ln -sf (pwd)/pre-commit.fish .git/hooks/pre-commit
   ```

The CI workflow will automatically check formatting, and PRs with incorrect formatting may be automatically fixed or rejected.

## Testing

Before submitting a pull request, please run the test suite:

```fish
./tests/run_tests.fish
