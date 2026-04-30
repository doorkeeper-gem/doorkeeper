# Doorkeeper Codebase Guide for AI Coding Agents

This is the code base of the OAuth 2 provider for Ruby web applications.

## Architecture Overview

Doorkeeper is a Ruby gem which is a Rails engine. It provides a set of models, controllers, and views that can be
mounted into a Rails application to handle OAuth 2 authorization flows.

**Key principle**: all the changes should conform OAuth 2 published specifications such as RFC 6749, RFC 6819 and etc.

## Testing Commands
 
From within the root directory (preferred method):

```bash
bundle exec rake spec
```

## Code Conventions

### Changelog Updates

When fixing bugs or adding features:

- Add an entry to the top of `CHANGELOG.md`
- Format: `- [PR number] Brief description`
- See existing entries for style

### Code Style

- Run RuboCop: `bundle exec rubocop` (there's a project-wide `.rubocop.yml`)

## Documentation

- API docs use YARD/RDoc format
