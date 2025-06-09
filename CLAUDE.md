# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a containerized full-stack development environment featuring:
- **Backend**: Loco (Rust web framework) running on port 5150
- **Frontend**: Next.js running on port 3000  
- **Database**: PostgreSQL (port 5432)
- **Cache/Queues**: Redis (port 6379)
- **Email Testing**: MailTutan SMTP server (ports 1080 UI, 1025 SMTP)

The setup uses Docker Compose with a multi-stage Dockerfile that combines Rust and Node.js in a Debian-based environment.

## Development Environment Setup

The application runs inside a Dev Container with user `utakata`. All services are interconnected via Docker networks (db, redis, mailer).

### Backend Auto-Boot Configuration

For frontend-focused development with the backend constantly running, use the configuration in `backend_boot/`:

```bash
# Use the auto-boot configuration (from backend_boot directory)
docker compose -f backend_boot/booting-compose.yaml up -d

# Or rebuild with backend auto-start
docker compose -f backend_boot/booting-compose.yaml up --build
```

This configuration separates services into:
- **`app`** - Frontend development container (uses existing Dockerfile, DevContainer attaches here)
- **`loco`** - Backend service (Rust-only, automatically runs `cargo loco start --server-and-worker`)

### Optimized Dockerfiles
The `backend_boot/` configuration uses:
- **`app` service** - Uses the main `Dockerfile` (full Node.js + Rust environment for monorepo development)
- **`booting-dockerfile-backend`** - Lightweight Rust-only environment for backend execution

You can focus on frontend development in the `app` container while the backend runs continuously in the `loco` service.

### Environment Configuration
- Copy `.env.example` to `.env` before starting development
- Key environment variables include database URLs, Redis URL, SMTP settings, and JWT secrets
- Cargo builds are cached in `/tmp/target` for performance

### Service Ports
- Next.js frontend: http://localhost:3000
- Loco backend API: http://localhost:5150  
- PostgreSQL: localhost:5432
- Redis: localhost:6379
- MailTutan Web UI: http://localhost:1080
- SMTP Server: localhost:1025

## Common Development Commands

### Container Management
```bash
# Start all services (standard mode)
docker compose up -d

# Start with backend auto-boot
docker compose -f backend_boot/booting-compose.yaml up -d

# Rebuild containers
docker compose up --build

# View logs
docker compose logs app
docker compose logs db

# Monitor backend in auto-boot mode
docker compose -f backend_boot/booting-compose.yaml logs -f loco

# Monitor all services in auto-boot mode
docker compose -f backend_boot/booting-compose.yaml logs -f
```

### Backend (Loco/Rust)
```bash
# Install Rust dependencies
cargo build

# Run with hot reload
cargo watch -x run

# Run database migrations
cargo loco db migrate

# Generate new migration
cargo loco db generate migration <name>

# Run tests
cargo test

# Lint code
cargo clippy

# Format code
cargo fmt
```

### Frontend (Next.js)
```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Run tests
npm test

# Lint code
npm run lint
```

### Database Operations
```bash
# Connect to PostgreSQL
psql postgres://loco:loco@localhost:5432/loco_app

# Check database health
pg_isready -h localhost -p 5432 -U loco -d loco_app
```

### Monorepo Development
```bash
# Work on both frontend and backend from same workspace
cd /workspaces

# Frontend development (in app container)
npm run dev                    # Start Next.js dev server
npm install                    # Install frontend dependencies

# Backend development (in app container - backend runs in loco service)
cargo build                    # Build Rust backend
cargo fmt                      # Format Rust code
cargo clippy                   # Lint Rust code
cargo loco db migrate          # Run backend migrations

# Full-stack workflow
npm run build                  # Build frontend for production
```

## Project Structure Notes

- **Monorepo Support**: `app` container has full Node.js + Rust tools for cross-technology development
- **Service Separation**: `loco` service runs Rust backend only, `app` service handles development
- **Shared Caches**: Cargo registry, NPM cache, and build targets are volume-mounted for performance
- **Development Workflow**: Develop in `app` container while backend runs automatically in `loco` service
- **VS Code Extensions**: Pre-configured for Rust, TypeScript, and database development
- **Format-on-save**: Disabled by default to prevent conflicts
- **File Watchers**: Exclude build directories and caches for performance