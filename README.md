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
- MinIO (self-hosted, S3-compatible storage) — Cloudflare R2/AWS S3 compatible via the same code path, see Key Decisions
- Docker / Docker Compose
- Daphne

### Mobile
- Flutter
- Dio
- GetX (state management, dependency injection, routing)
- flutter_secure_storage
- web_socket_channel
- cached_network_image

Since GetX is already familiar, it lets development focus on architecture, API integration, and engineering practices rather than learning a new state management solution.

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
- [x] Project setup
- [x] Docker, PostgreSQL, Redis
- [x] Environment configuration
- [x] Authentication (register, login, refresh, logout with token blacklisting)
- [x] User profiles
- [x] drf-spectacular wired up, schema live at `/api/schema/`

**Deliverable:** A clean authentication system using JWT, with a live API schema. ✅ Done — proven end-to-end on both backend (Swagger) and mobile (Flutter auth flow with secure token storage and auto-refresh).

### Phase 2 — Tweets
- [x] Create Tweet
- [x] Delete Tweet (soft delete, author-only)
- [x] Timeline (filtered by following + own tweets)
- [x] Pagination (cursor-based)
- [x] Replies

**Deliverable:** A functional Twitter-like feed. ✅ Done — end-to-end on backend and mobile, including following-based filtering.

### Phase 3 — Social Features
- [x] Follow / Unfollow
- [x] Likes
- [x] Retweets (including original-tweet display, retweet-of-a-retweet blocked)
- [x] User profiles
- [x] Counts (computed at read time — see Key Decisions)

**Deliverable:** Core social interactions. ✅ Done — follow, likes, retweets, and profiles all working end-to-end on backend and mobile.

### Phase 4 — Real-Time
- [x] Django Channels
- [x] Redis (channel layer)
- [x] WebSockets (JWT-authenticated consumer)
- [x] Notifications (REST + live push via signals)
- [x] Live updates (mobile socket client, unread badge)

**Deliverable:** Real-time interactions. ✅ Done — likes, follows, replies, and retweets push a live notification to the recipient's device via WebSocket, with a REST fallback for history/pagination.

### Phase 5 — Media
- [x] S3-compatible storage (MinIO locally; R2/S3-compatible via the same code)
- [x] Presigned uploads
- [ ] Avatar upload
- [x] Tweet image upload

**Deliverable:** Direct client uploads without routing files through Django. ✅ Done for tweet images — client uploads directly to storage via a presigned URL; Django only issues the URL and links the result to the tweet. Avatar upload not yet built (same pattern, smaller scope).

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
│   ├── core/               # App-wide shared layers (never feature-specific)
│   │   ├── constants/
│   │   ├── theme/
│   │   └── network/        # Dio client, token storage, refresh interceptor
│   │
│   ├── features/
│   │   ├── authentication/
│   │   │   ├── data/         # API calls, local storage persistence
│   │   │   ├── domain/       # Models, GetX controllers
│   │   │   └── presentation/ # Screens, feature-specific widgets
│   │   │
│   │   └── dashboard/
│   │       ├── data/
│   │       ├── domain/
│   │       └── presentation/
│   │
│   ├── shared/
│   │   └── widgets/         # Reusable buttons, error text, tweet card, etc.
│   │
│   └── main.dart            # Thin entry point — DI, theme, routing only
│
└── pubspec.yaml
```

Feature-based organization scales better than placing every screen in a single `screens/` folder, especially with more than one person contributing. The `data → domain → presentation` split inside each feature keeps API calls, state/business logic, and UI cleanly separated.

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

## Key Decisions

A running log of non-obvious architectural choices and why they were made. Full detail for each lives in `docs/Decisions.md`; this is the summary.

### Database schema
- **`display_name` and `username` are separate fields** on `User` — a handle (`@jacob`, unique, effectively fixed) is a different concern from a shown name (`Jacob Mwangi`, mutable, not unique). Conflating them is a common early mistake that's painful to unwind later.
- **`visibility` on `Tweet` is scaffolded but not enforced.** The field exists (`PUBLIC` / `FOLLOWERS`) so adding real private-tweet support later is a query change, not a migration. Only `PUBLIC` behavior is implemented right now.
- **Retweets are `Tweet` rows with a self-referential `retweet_of` FK**, not a separate `Retweet` table. Keeps the timeline query a single `filter()` instead of a `UNION` across tables. A retweet with its own `content` is rejected at the serializer level (that's a quote tweet, out of scope for now).
- **Replies use a simple `parent` self-FK (adjacency list)**, not a nested-set or closure table. Sufficient for this project's depth of threading; revisit only if deep-thread query performance actually becomes a problem.
- **`Media` is its own table from the start**, not an `image_url` column on `Tweet` — the migration from single-image to multi-image/video later would otherwise be painful for very little upfront cost now.
- **Counts (`like_count`, `reply_count`, `retweet_count`, `follower_count`, `following_count`) are computed at read time**, not denormalized columns. Deliberately deferred optimization — start correct and simple, denormalize only once real latency is observed. Documents an evolving-design story rather than a premature one.
- **Soft delete via `deleted_at`** on `Tweet`, not hard delete — prevents orphaned replies when a parent tweet is removed; every queryset filters `deleted_at__isnull=True`.
- **Self-follow is blocked at two layers**: a Postgres `CheckConstraint` on `Follow` (DB-level guarantee) and `full_clean()` validation in the view (clean `400` response instead of a raw DB error).
- **Follow is idempotent** — following twice succeeds silently rather than erroring, simplifying client logic (no "am I already following?" check needed before the request).
- **JOIN tables (`TweetHashtag`, `Mention`) have no `created_at`/`updated_at`** — rows are immutable once created, so audit timestamps add nothing.

### Backend
- **Timeline query is computed at read time** (`Tweet.objects.filter(author__in=following_ids)`), not fan-out-on-write. Correct tradeoff at this scale; fan-out is a real system-design problem not worth solving here.
- **`RefreshToken` blacklist is provided by `rest_framework_simplejwt.token_blacklist`**, not modeled manually — a solved problem in the library, not reimplemented.
- **Logout blacklists the refresh token, not the access token.** Access tokens are short-lived (30 min) and stateless by design; there's no cheap way to revoke one early without extra infrastructure (Redis-backed revocation list, token versioning), which is overkill here. A leaked access token remains valid until natural expiry — a known, accepted JWT tradeoff.
- **DRF's `CursorPagination` requires an explicit `ordering`** matching the actual model field name — it defaults to `'-created'`, which silently doesn't exist on models using `created_at`. Fixed via a shared `apps/common/pagination.py` (`CreatedAtCursorPagination`) reused across all list endpoints, rather than patching each view.
- **API contract is the live OpenAPI schema** (drf-spectacular), not a hand-maintained doc — see [API Contract & Schema Sharing](#api-contract--schema-sharing) above.

### Mobile
- **GetX over Provider/Bloc** — already familiar, so development time goes into architecture and API integration rather than learning new state management. Trade-off: a future collaborator unfamiliar with GetX has more to learn upfront than with a lighter, single-purpose package.
- **Folder structure follows `core / features / shared`**, with each feature split into `data / domain / presentation`. `core` holds only app-wide, never feature-specific code (network client, theme, constants). `shared/widgets` holds UI reused across features (e.g. `PrimaryButton`, `TweetCard`) so it's built once, not duplicated per screen.
- **`main.dart` stays thin** — DI registration, theme, and root routing only. Theme and constants are extracted (`core/theme`, `core/constants`) rather than left inline.
- **Concurrent 401s trigger only one token refresh call**, queued and resolved together, rather than each in-flight request independently trying to refresh — avoids a race where simultaneous requests step on each other's refresh attempt.
- **Navigation is state-driven, not screen-driven** — screens update controller state (e.g. `AuthController.status`) rather than calling `Navigator`/`Get.to` themselves to reach a new app-level state; a root `AuthGate` widget reacts to that state. Keeps navigation logic in one place.
- **Long-lived, app-wide controllers vs. screen-scoped state**: `AuthController` is registered once in `main.dart` and lives for the app's lifetime since auth state is genuinely global. Screen-local concerns (like a shared `errorMessage` briefly leaking between login and signup — see fix history) are a reminder to keep anything screen-local out of a long-lived controller where possible, or explicitly clear it on screen entry.
- **Tweet feed deletion is optimistic** — removed from local state immediately on delete, re-inserted only if the API call fails. Keeps the UI feeling instant.

### Real-time (Django Channels)
- **Notification creation is signal-based, not inline in the views.** `apps/notifications/signals.py` listens for `post_save` on `Like`, `Follow`, and `Tweet` (for replies/retweets) rather than `LikeToggleView`/`FollowToggleView`/`TweetListCreateView` each explicitly creating a `Notification`. Decouples `notifications` from `tweets`/`accounts` entirely — neither needs to import it. Trade-off: "what triggers a notification" isn't visible by reading the view that performs the action; you have to know to check `signals.py`.
- **WebSocket auth is a JWT passed as a query parameter** (`?token=<access>`), not a header — browsers' native WebSocket API can't set custom headers on the handshake, so this is the standard workaround. A custom `JWTAuthMiddleware` validates it and sets `scope['user']` before the connection reaches the consumer.
- **Each user joins a group scoped to their own id** (`notifications_{user_id}`), so a pushed notification only reaches that specific user's connection(s), not a broadcast.
- **`redis-py` is pinned below 6.0** — `channels_redis` 4.3.0 is incompatible with `redis-py` 8.x (an untested major-version jump ahead of `channels_redis`'s support matrix), which caused WebSocket connections to crash with a `TimeoutError` shortly after connecting. Diagnosed by isolating Redis/Docker networking as healthy first (a standalone script using the same blocking-read pattern worked fine), narrowing it to the library versions.
- **No auto-reconnect on the mobile socket client.** If the connection drops (backgrounding, network hiccup), it reconnects on next app open (via the same `AuthController.status` listener that connected it originally), not automatically mid-session. Accepted simplification for this project's scope.

### Media
- **MinIO (self-hosted via Docker) instead of Cloudflare R2** — R2's free tier requires a card on file; MinIO needs no external account at all and runs alongside the existing Postgres/Redis containers. Both are S3-compatible, so the same `boto3` presigning code works unchanged — switching to real R2/S3 later is purely an `.env` change.
- **`Media` rows are created atomically with the tweet, not at upload time.** The presigned-upload endpoint only issues a signed URL; no DB row exists until the tweet itself is created with that URL attached. An upload the user abandons never leaves an orphaned `Media` row (though the uploaded object itself would still exist in storage — a known, accepted gap for this scope).
- **Presigning needs no network connectivity to storage at request time.** Generating a presigned URL is local cryptographic signing — `boto3` never actually connects to MinIO/R2 to do it. This matters for local dev: the URL's host just needs to be reachable by whoever performs the upload (the mobile client), not by the Django backend that signs it.
- **The storage upload uses a separate, bare `Dio()` instance on mobile, never `DioClient`.** The presigned URL carries its own auth via its signature; running it through the app's normal API client would leak the API's `Authorization` header onto an unrelated storage request and risk the 401-refresh interceptor misfiring on it.

## Docker Strategy

Run every backend dependency through Docker Compose:

- Django
- PostgreSQL
- Redis
- MinIO (S3-compatible media storage)
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

✅ Phases 1–5 complete end-to-end (backend + mobile): auth, tweets (CRUD, replies, cursor pagination, following-based timeline), social features (follow/unfollow, likes, retweets, profiles), real-time notifications (WebSocket push via Django Channels), and media (presigned direct-to-storage image uploads on tweets).

🚧 Phase 6 — Production Readiness is next: automated tests (currently none), structured logging, a consistent API error-response shape, and deployment documentation. `docs/Decisions.md` also still needs to be written as an actual file — the material exists (see Key Decisions above) but hasn't been consolidated into `docs/` yet.