# Project Architecture: new-abify (Backend)

## Executive Summary
This document outlines the architecture of the 'new-abify' project, identified as a monolithic Ruby on Rails backend application. It details the technology stack, architectural patterns, data and API design, source tree, and development/deployment workflows.

## Technology Stack
- **Language:** Ruby
- **Framework:** Ruby on Rails
- **Database:** Relational DB (Specific type to be detailed in deep/exhaustive scan)
- **Orchestration:** Docker / Docker Compose

## Architecture Pattern
**Monolithic Web Application (MVC-based)**
The application follows a traditional Model-View-Controller (MVC) pattern, characteristic of Ruby on Rails applications.

## Data Architecture
Data models are defined using ActiveRecord in `app/models/` and managed through database migrations in `db/migrate/`.
*(To be generated: Detailed Data Models - see data-models-main.md for more info)*

## API Design
API endpoints are routed via `config/routes.rb` and implemented in `app/controllers/`. Business logic is handled by a service layer in `app/services/`.
*(To be generated: Detailed API Contracts - see api-contracts-main.md for more info)*

## Component Overview
As a backend application, the primary components are Controllers, Models, and Services. No explicit UI component inventory applies directly.

## Source Tree
```
new-abify/
├── app/                  # Application core
│   ├── controllers/      # Handles web requests, defines API endpoints
│   ├── models/           # Defines database models and relationships
│   ├── services/         # Business logic and service objects
│   └── views/            # (Potentially for UI, even if backend-focused)
├── config/               # Configuration files
│   └── routes.rb         # Defines URL routing and API endpoints
├── db/                   # Database related files
│   └── migrate/          # Database migration scripts
├── lib/                  # Shared libraries and utility modules
├── public/               # Static assets (images, stylesheets, JavaScript)
├── Dockerfile            # Containerization definition
├── docker-compose.yml    # Defines multi-container Docker application
├── Gemfile               # Ruby gem dependencies
├── Gemfile.lock          # Exact gem versions
├── Rakefile              # Ruby build and task automation
├── README.md             # Project overview and introduction
└── docs/                 # Project documentation
    └── auth_config.md    # Existing authentication configuration document
```

## Development Workflow
- **Prerequisites:** Ruby, Bundler
- **Installation:** `bundle install`
- **Environment Setup:** `config/` directory, `.env` files (e.g., `.posting/.env`)
- **Build/Task Commands:** `rake` commands
- **Run Commands:** `rails server` (via `Procfile.dev`)
- **Testing Strategy:** RSpec (tests located in `spec/` directory)

## Deployment Architecture
The application is containerized using `Dockerfile` and orchestrated with `docker-compose.yml` for development and deployment. No explicit CI/CD pipelines or Infrastructure as Code were identified in this quick scan.

## Testing Strategy
The project uses RSpec for testing, with test files located in the `spec/` directory.
