# Chirp

An X (Twitter) clone — a structured engineering exercise in backend, mobile, database, DevOps, and software architecture, built as a professional refresh before starting development on the Compixel Platform.

## Project Goal

This project is not intended to be a production competitor to X.

It is a structured exercise to rebuild professional development habits — clean architecture, maintainable code, testing, documentation, and Dockerized development — rather than to maximize features.

The emphasis is on:

- Clean architecture
- Maintainable code
- Testing
- Documentation
- Dockerized development
- Production-ready engineering practices

## Technology Stack

### Backend
- Python 3.11+
- Django
- Django REST Framework
- drf-spectacular — OpenAPI/Swagger schema generation
- Django Channels
- Celery
- PostgreSQL
- Redis
- Simple JWT
- Cloudflare R2 (S3-compatible storage)
- Docker / Docker Compose
- Daphne

### Mobile
- Flutter
- Dio
- GetX (state management, dependency injection, routing)
- flutter_secure_storage
- web_socket_channel
- cached_network_image


## API Contract & Schema Sharing

The backend exposes a live OpenAPI schema via **drf-spectacular**, generated directly from the DRF serializers and views. This is the single source of truth for the API contract between backend and mobile — not a hand-maintained doc that drifts out of sync.

- Schema endpoint: `/api/schema/`
- Interactive docs: `/api/schema/swagger-ui/`
- Collaborators can generate/inspect request-response shapes directly from this schema instead of reading backend source or waiting on manual docs
- Breaking changes to the API should be visible as diffs in the generated schema, and noted in `docs/API.md`
- Where useful, the schema can also drive typed API client generation for the Flutter side, reducing manual model-mapping errors

This is set up from Phase 1 onward so the contract exists before mobile work depends on it.

## Development Philosophy

Every feature should satisfy:

- Single responsibility
- Modular architecture
- Reusable components
- Consistent naming
- Proper validation
- Proper exception handling
- Logging
- Testing where appropriate
- Documentation

The goal is code that another developer could comfortably maintain.

## Development Roadmap

### Phase 1 — Foundation
- Project setup
- Docker, PostgreSQL, Redis
- Environment configuration
- Authentication
- User profiles
- drf-spectacular wired up, schema live at `/api/schema/`

**Deliverable:** A clean authentication system using JWT, with a live API schema.

### Phase 2 — Tweets
- Create Tweet
- Delete Tweet
- Timeline
- Pagination
- Replies

**Deliverable:** A functional Twitter-like feed.

### Phase 3 — Social Features
- Follow / Unfollow
- Likes
- Retweets
- User profiles
- Counts

**Deliverable:** Core social interactions.

### Phase 4 — Real-Time
- Django Channels
- Redis
- WebSockets
- Notifications
- Live updates

**Deliverable:** Real-time interactions.

### Phase 5 — Media
- Cloudflare R2
- Presigned uploads
- Avatar upload
- Tweet image upload

**Deliverable:** Direct client uploads without routing files through Django.

### Phase 6 — Production Readiness
- Docker Compose
- API documentation
- Automated tests
- Logging
- Error handling
- Deployment

**Deliverable:** A project that can be deployed with minimal changes.

## Folder Structure

### Backend
```
backend/
│
├── config/
│
├── apps/
│   ├── accounts/
│   ├── tweets/
│   ├── notifications/
│   ├── media/
│   ├── common/
│   └── search/
│
├── tests/
│
├── docs/
│
├── docker/
│
├── requirements/
│
└── manage.py
```

### Mobile
```
mobile/
│
├── lib/
│   ├── core/
│   │
│   ├── data/
│   │
│   ├── features/
│   │   ├── auth/
│   │   ├── home/
│   │   ├── profile/
│   │   ├── tweet/
│   │   ├── notifications/
│   │   └── search/
│   │
│   ├── shared/
│   │
│   └── main.dart
│
└── pubspec.yaml
```

Feature-based organization scales better than placing every screen in a single `screens/` folder, especially with more than one person contributing.

## Git Workflow

Use meaningful, scoped commits throughout development.

Examples:
```
feat(auth): implement JWT authentication
feat(tweet): create tweet endpoint
feat(feed): add cursor pagination
feat(notification): websocket consumer
refactor(accounts): simplify serializers
test(tweet): add API tests
docs(api): document tweet endpoints
```

Branch naming: `feature/<short-description>` or `fix/<short-description>`. Open a PR into `main` for review before merging.

## Documentation

Maintain documentation from the beginning, under `docs/`:

- `Architecture.md`
- `Database.md`
- `API.md`
- `Authentication.md`
- `Deployment.md`
- `Testing.md`
- `Decisions.md` — record architectural decisions as they're made (e.g. why GetX, why read-time timeline queries)

## Docker Strategy

Run every backend dependency through Docker Compose:

- Django
- PostgreSQL
- Redis
- Celery Worker
- Celery Beat
- Daphne

This mirrors a production-style environment and ensures a consistent local setup for every contributor.

## Success Criteria

The project will be considered complete when it demonstrates:

- Clean project structure
- Secure JWT authentication
- Well-designed REST APIs with a live, shareable OpenAPI schema
- Modular Flutter application
- Real-time notifications
- Dockerized development
- PostgreSQL integration
- Redis integration
- Cloud media storage
- Automated testing for key functionality
- Comprehensive documentation
- Straightforward deployment process

## Status

🚧 Phase 1 — Foundation in progress.
