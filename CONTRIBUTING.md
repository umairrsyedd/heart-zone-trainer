# Contributing to Heart Zone Trainer

First off, thank you for considering contributing to Heart Zone Trainer! It's people like you that make this app better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by our commitment to providing a welcoming and inclusive experience. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates.

When creating a bug report, include:

- **Device information** (model, Android version)
- **Heart rate monitor** used (brand, model)
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **Screenshots** if applicable
- **Logs** if available

### Suggesting Features

Feature suggestions are welcome! Please:

- Check if the feature has already been suggested
- Provide a clear description of the feature
- Explain why this feature would be useful
- Include mockups if applicable

### Pull Requests

1. Fork the repo and create your branch from `main`
2. If you've added code that should be tested, add tests
3. Ensure your code follows the existing style
4. Run `flutter analyze` and fix any issues
5. Run `dart format .` to format your code
6. Update documentation if needed
7. Create the Pull Request

## Development Setup

1. Fork and clone the repository
2. Run `flutter pub get`
3. Run `dart run build_runner build --delete-conflicting-outputs`
4. Make your changes
5. Test with a real BLE heart rate monitor if possible

## Style Guide

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused
- Use Riverpod for state management
- Use Freezed for data models

## Commit Messages

- Use present tense ("Add feature" not "Added feature")
- Use imperative mood ("Move cursor to..." not "Moves cursor to...")
- Keep first line under 72 characters
- Reference issues and PRs where appropriate

Examples:

```
Add voice alert for zone changes
Fix BLE reconnection issue on Android 12
Update zone calculation to use Karvonen formula
```

## Questions?

Feel free to open an issue with your question or reach out via email.

Thank you for contributing! ❤️
