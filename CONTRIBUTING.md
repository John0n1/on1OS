# Contributing to on1OS

Thank you for considering contributing to on1OS! We welcome contributions from the community.

## Development Setup

1. **Fork the repository**
   ```bash
   # Fork on GitHub, then clone your fork
   git clone https://github.com/YOUR_USERNAME/on1OS.git
   cd on1OS
   git remote add upstream https://github.com/John0n1/on1OS.git
   ```

2. **Set up development environment**
   ```bash
   make setup      # Install build dependencies
   make config-dev # Configure for development
   ```

3. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Types of Contributions

### 🐛 Bug Reports
- Use the GitHub issue tracker
- Include system information and steps to reproduce
- Provide build logs if relevant

### 🚀 Feature Requests
- Open an issue with the "enhancement" label
- Describe the use case and expected behavior
- Consider security implications

### 🔧 Code Contributions
- Follow the coding standards below
- Include tests where applicable
- Update documentation as needed

### 📚 Documentation
- Improve existing documentation
- Add examples and tutorials
- Fix typos and clarify instructions

## Coding Standards

### Shell Scripts
- Use `#!/bin/bash` shebang
- Set `set -e` for error handling
- Use meaningful variable names
- Include comments for complex logic
- Follow Google Shell Style Guide

### Configuration Files
- Use consistent indentation (2 spaces)
- Group related settings
- Include inline comments for non-obvious settings

### Commit Messages
Follow conventional commits format:
```
type(scope): description

[optional body]

[optional footer]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
- `feat(kernel): add support for new security feature`
- `fix(build): resolve compilation error on Ubuntu 22.04`
- `docs(readme): update installation instructions`

## Security Guidelines

### Security-Related Changes
- Security fixes have priority
- Include CVE numbers if applicable
- Coordinate with maintainers for disclosure

### Cryptographic Components
- Use well-established algorithms
- Avoid rolling your own crypto
- Follow current best practices

### Code Review
- All security-related changes require review
- Test security features thoroughly
- Document security implications

## Testing

### Build Testing
```bash
make test           # Run all tests
make test-build     # Test build process
make test-kernel    # Test kernel compilation
make test-rootfs    # Test rootfs creation
```

### Virtual Machine Testing
```bash
make test-vm        # Test in QEMU/KVM
make test-vm-secure # Test with TPM2 and Secure Boot
```

### Hardware Testing
- Test on real hardware when possible
- Verify TPM2 and Secure Boot functionality
- Document tested hardware configurations

## Documentation Standards

### Code Documentation
- Comment complex algorithms
- Explain security-related decisions
- Include examples for configuration options

### User Documentation
- Write for different skill levels
- Include troubleshooting sections
- Provide step-by-step instructions

### API Documentation
- Document all public interfaces
- Include parameter descriptions
- Provide usage examples

## Pull Request Process

1. **Before Submitting**
   - Ensure all tests pass
   - Update relevant documentation
   - Rebase on latest main branch

2. **PR Description**
   - Clearly describe the changes
   - Reference related issues
   - Include testing performed

3. **Review Process**
   - Address reviewer feedback
   - Keep commits focused and atomic
   - Squash commits if requested

4. **Merge Requirements**
   - At least one maintainer approval
   - All CI checks must pass
   - Documentation must be updated

## Release Process

### Version Numbering
We follow semantic versioning (SemVer):
- `MAJOR.MINOR.PATCH`
- Security fixes increment PATCH
- New features increment MINOR
- Breaking changes increment MAJOR

### Release Schedule
- Regular releases every 3-6 months
- Security releases as needed
- LTS releases annually

## Getting Help

### Communication Channels
- GitHub Discussions for general questions
- GitHub Issues for bugs and features
- Security issues: email maintainers directly

### Resources
- [Project Wiki](https://github.com/John0n1/on1OS/wiki)
- [Development Documentation](docs/DEVELOPER.md)
- [Security Guidelines](docs/SECURITY.md)

## Code of Conduct

### Our Standards
- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow
- Prioritize security and user safety

### Enforcement
- Report issues to project maintainers
- Violations may result in temporary or permanent bans
- Follow GitHub's Community Guidelines

## Recognition

Contributors will be recognized in:
- `CONTRIBUTORS.md` file
- Release notes
- Annual contributor highlights

Thank you for helping make on1OS better and more secure! 🛡️
