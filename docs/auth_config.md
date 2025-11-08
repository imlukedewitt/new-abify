# Authentication Configuration

This document explains how to configure authentication for API requests in workflows, including the new `Connection` model for managing encrypted credentials.

## Overview

There are two ways to configure authentication:

1. **Connection Model (Recommended)**: Create reusable, encrypted connection objects
2. **Workflow Config (Legacy)**: Store auth directly in workflow config JSON

## Authentication Methods

The following authentication methods are supported:

1. **Basic Authentication** (`type: :basic`)
2. **Bearer Token Authentication** (`type: :bearer`)
3. **API Key Authentication** (`type: :api_key`)
4. **OAuth2 Authentication** (`type: :oauth2`)
5. **Custom Header Authentication** (`type: :custom`)

## Using the Connection Model (Recommended)

The `Connection` model stores encrypted credentials that can be reused across multiple workflows.

### Creating a Connection

```ruby
user = User.find(1)

connection = Connection.create(
  user: user,
  name: "Salesforce Production",
  handle: "salesforce_prod",  # Used to reference in configs
  credentials: {
    type: 'bearer',
    token: 'your_secret_token'
  }
)
```

### Using a Connection in a Workflow

```ruby
workflow = Workflow.create(
  name: "Sync Leads",
  connection: connection  # Reference the connection
)
```

That's it! All steps in the workflow will automatically use the connection's credentials.

### Benefits

- **Encrypted Storage**: Credentials are encrypted using Rails' built-in encryption
- **Reusable**: Use the same connection across multiple workflows
- **Centralized Management**: Update credentials in one place
- **User-scoped**: Each user manages their own connections

### Handle Format

Connection handles must:
- Start with a lowercase letter
- Contain only lowercase letters, numbers, and underscores
- Be unique per user

Examples: `salesforce_prod`, `slack_workspace`, `api_key_123`

## Using Environment Variables for Authentication (Alternative)

For system-level integrations or self-hosted deployments, you can use environment variables.

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

## Legacy: Workflow Config Auth (Backwards Compatible)

You can still store auth directly in workflow config (not encrypted):

```ruby
workflow.config = {
  'connection' => {
    'auth' => {
      'type' => 'bearer',
      'token' => 'your_token'
    }
  }
}
```

**Note**: This method is deprecated in favor of the Connection model for better security and reusability.

## Authentication Resolution Priority

When executing a workflow step, authentication is resolved in this order:

1. **Explicit auth_config parameter** (if passed to StepExecutor)
2. **Step-level config auth** (in step.config['auth'])
3. **Workflow connection** (workflow.connection.credentials)
4. **Workflow config auth** (workflow.config['connection']['auth'])
5. **Empty hash** (no authentication)

This allows for flexible auth configuration at different levels.
