# Authentication Configuration in HydraManager

The `HydraManager` class supports various authentication methods when making API requests. This document explains how to configure authentication, particularly focusing on how to secure sensitive credentials using environment variables.

## Authentication Methods

HydraManager supports the following authentication methods:

1. **Basic Authentication** (`type: :basic`)
2. **Bearer Token Authentication** (`type: :bearer`)
3. **API Key Authentication** (`type: :api_key`)
4. **OAuth2 Authentication** (`type: :oauth2`)
5. **Custom Header Authentication** (`type: :custom`)

## Using Environment Variables for Authentication

For sensitive credentials like API keys and tokens, it's recommended to use environment variables rather than hardcoding them in your configuration.

### Environment Variable Format

When providing an `env_key` in your authentication configuration, HydraManager will look for environment variables in the following format:

- For Basic Auth username: `AUTH_BASIC_USER_[ENV_KEY]`
- For Basic Auth password: `AUTH_BASIC_PASS_[ENV_KEY]`
- For Bearer tokens: `AUTH_BEARER_[ENV_KEY]`
- For API keys: `AUTH_APIKEY_[ENV_KEY]`
- For OAuth2 tokens: `AUTH_OAUTH_[ENV_KEY]`

Where `[ENV_KEY]` is replaced with the value of the `env_key` parameter in your authentication config.

### Authentication Configuration Examples

#### Basic Authentication

```ruby
# Using environment variables (recommended)
auth_config = {
  type: :basic,
  env_key: 'DB_SERVICE'  # Will look for ENV['AUTH_BASIC_USER_DB_SERVICE'] and ENV['AUTH_BASIC_PASS_DB_SERVICE']
}

# Direct configuration (not recommended for production)
auth_config = {
  type: :basic,
  username: 'api_user',
  password: 'password123'
}
```

#### Bearer Token Authentication

```ruby
# Using environment variable (recommended)
auth_config = {
  type: :bearer,
  env_key: 'GITHUB_API'  # Will look for ENV['AUTH_BEARER_GITHUB_API']
}

# Direct configuration (not recommended for production)
auth_config = {
  type: :bearer,
  token: 'your_secret_token'
}
```

#### API Key Authentication

```ruby
# Using environment variable (recommended)
auth_config = {
  type: :api_key,
  header_name: 'X-API-KEY',
  env_key: 'WEATHER_SERVICE'  # Will look for ENV['AUTH_APIKEY_WEATHER_SERVICE']
}

# Direct configuration (not recommended for production)
auth_config = {
  type: :api_key,
  header_name: 'X-API-KEY',
  value: 'your_api_key'
}
```

#### OAuth2 Authentication

```ruby
# Using environment variable (recommended)
auth_config = {
  type: :oauth2,
  env_key: 'AUTH0_SERVICE'  # Will look for ENV['AUTH_OAUTH_AUTH0_SERVICE']
}

# Direct configuration (not recommended for production)
auth_config = {
  type: :oauth2,
  token: 'your_oauth_token'
}
```

#### Custom Headers Authentication

```ruby
auth_config = {
  type: :custom,
  headers: {
    'X-Client-ID': 'client123',
    'X-App-Version': '1.0.0'
  }
}
```

## Setting Up Environment Variables

### Development Environment

Add to your `.env` file (don't commit this file to version control):

```
AUTH_BASIC_USER_DB_SERVICE=admin_user
AUTH_BASIC_PASS_DB_SERVICE=secure_password
AUTH_BEARER_GITHUB_API=gh_token_123456
AUTH_APIKEY_WEATHER_SERVICE=weather_api_key_789
AUTH_OAUTH_AUTH0_SERVICE=oauth_token_abc123
```
