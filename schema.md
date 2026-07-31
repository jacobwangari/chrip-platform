# Chirp — Database Schema

**Project:** Chirp (X/Twitter Clone) — Portfolio / Engineering Refresh
**Scope:** Core relational schema, organized by Django app (bounded context)
**Source of truth:** `schema.dbml` (paste into [dbdiagram.io](https://dbdiagram.io) to visualize)

---

## Contents

- [Overview](#overview)
- [App: accounts](#app-accounts)
  - [User](#user)
  - [Follow](#follow)
- [App: tweets](#app-tweets)
  - [Tweet](#tweet)
  - [Media](#media)
  - [Like](#like)
  - [Bookmark](#bookmark)
  - [Hashtag](#hashtag)
  - [TweetHashtag](#tweethashtag)
  - [Mention](#mention)
- [App: notifications](#app-notifications)
  - [Notification](#notification)
- [Entity Relationship Summary](#entity-relationship-summary)
- [Design Decisions](#design-decisions)
- [Deliberately Omitted Tables](#deliberately-omitted-tables)

---

## Overview

The schema is split into three Django apps, each owning a bounded context:

| App | Responsibility | Tables |
|---|---|---|
| `accounts` | Identity and the social graph | `User`, `Follow` |
| `tweets` | Content, engagement, and content graph (hashtags/mentions) | `Tweet`, `Media`, `Like`, `Bookmark`, `Hashtag`, `TweetHashtag`, `Mention` |
| `notifications` | Cross-cutting activity feed | `Notification` |

All primary keys are auto-incrementing `bigint` unless the table is a pure join table, in which case a composite primary key is used instead.

---

## App: `accounts`

### User

The root entity. Every other table ultimately hangs off `User.id`.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK, increment | |
| `username` | varchar(30) | not null, unique | Handle, e.g. `@jacob` — unique, effectively immutable |
| `email` | varchar(255) | not null, unique | |
| `password_hash` | varchar(255) | not null | |
| `display_name` | varchar(50) | not null | Shown name, e.g. "Jacob Mwangi" — mutable, **not** unique |
| `bio` | varchar(160) | | |
| `avatar_url` | varchar(500) | | |
| `banner_url` | varchar(500) | | |
| `location` | varchar(100) | | |
| `website` | varchar(255) | | |
| `is_verified` | boolean | not null, default `false` | |
| `is_active` | boolean | not null, default `true` | |
| `last_login` | timestamp | | |
| `created_at` | timestamp | not null, default `now()` | |
| `updated_at` | timestamp | not null, default `now()` | |

### Follow

Directed edge in the social graph.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK, increment | |
| `follower_id` | bigint | not null, FK → `User.id` | The user doing the following |
| `following_id` | bigint | not null, FK → `User.id` | The user being followed |
| `created_at` | timestamp | not null, default `now()` | |

**Indexes**

| Name | Columns | Type |
|---|---|---|
| `uq_follow_pair` | `(follower_id, following_id)` | unique |
| `ix_follow_follower` | `follower_id` | index |
| `ix_follow_following` | `following_id` | index |

> ⚠️ **Constraint note:** Self-follows (`follower_id = following_id`) must be rejected at the application/serializer layer, or via a DB `CHECK` constraint where supported (Postgres: `CHECK (follower_id <> following_id)`).

---

## App: `tweets`

### Tweet

Core content table. Both replies and retweets are modeled as self-referential rows rather than separate tables.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK, increment | |
| `author_id` | bigint | not null, FK → `User.id` | |
| `content` | varchar(280) | | |
| `visibility` | varchar(20) | not null, default `'PUBLIC'` | Enum-like: `PUBLIC` \| `FOLLOWERS` |
| `parent_id` | bigint | FK → `Tweet.id` | Set when this row is a reply |
| `retweet_of_id` | bigint | FK → `Tweet.id` | Set when this row is a retweet |
| `created_at` | timestamp | not null, default `now()` | |
| `updated_at` | timestamp | not null, default `now()` | |
| `deleted_at` | timestamp | | Soft delete marker |

**Indexes**

| Name | Columns |
|---|---|
| `ix_tweet_author_timeline` | `(author_id, created_at)` |
| `ix_tweet_parent` | `parent_id` |
| `ix_tweet_retweet_of` | `retweet_of_id` |

**Design notes**

- **`visibility`** — Only `PUBLIC` is enforced in this project's scope today; `FOLLOWERS` is scaffolded in the schema but not yet enforced in query logic.
- **Retweets** are `Tweet` rows with `retweet_of_id` set, rather than a separate `Retweet` table. This keeps timeline queries to a single filter instead of a `UNION` across tables.
- **Soft delete** via `deleted_at` (instead of a hard delete) allows replies to a deleted tweet to render a placeholder instead of becoming orphaned.
- **Engagement counts** (`like_count`, `retweet_count`, `reply_count`) are intentionally **not** stored on this table — they're computed at read time via aggregate queries. See `docs/Decisions.md` for the denormalization tradeoff.

### Media

Attachments belonging to a tweet.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK, increment | |
| `tweet_id` | bigint | not null, FK → `Tweet.id` | |
| `url` | varchar(500) | not null | |
| `media_type` | varchar(20) | not null | Enum-like: `IMAGE` \| `GIF` \| `VIDEO` |
| `position` | smallint | not null, default `0` | Ordering when a tweet has multiple media items |
| `created_at` | timestamp | not null, default `now()` | |

**Indexes:** `ix_media_tweet` on `tweet_id`

> Modeled as its own table (rather than a single `image_url` column on `Tweet`) so multi-image/video support doesn't require a later migration.

### Like

| Column | Type | Constraints |
|---|---|---|
| `id` | bigint | PK, increment |
| `user_id` | bigint | not null, FK → `User.id` |
| `tweet_id` | bigint | not null, FK → `Tweet.id` |
| `created_at` | timestamp | not null, default `now()` |

**Indexes**

| Name | Columns | Type |
|---|---|---|
| `uq_like_pair` | `(user_id, tweet_id)` | unique |
| `ix_like_tweet` | `tweet_id` | index |

### Bookmark

| Column | Type | Constraints |
|---|---|---|
| `id` | bigint | PK, increment |
| `user_id` | bigint | not null, FK → `User.id` |
| `tweet_id` | bigint | not null, FK → `Tweet.id` |
| `created_at` | timestamp | not null, default `now()` |

**Indexes**

| Name | Columns | Type |
|---|---|---|
| `uq_bookmark_pair` | `(user_id, tweet_id)` | unique |
| `ix_bookmark_user` | `user_id` | index |

> Not necessarily exposed in the UI — included to demonstrate relationship modeling.

### Hashtag

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK, increment | |
| `tag` | varchar(100) | not null, unique | Stored lowercase for case-insensitive lookups |
| `created_at` | timestamp | not null, default `now()` | |

### TweetHashtag

Pure join table linking tweets to hashtags.

| Column | Type | Constraints |
|---|---|---|
| `tweet_id` | bigint | not null, FK → `Tweet.id` |
| `hashtag_id` | bigint | not null, FK → `Hashtag.id` |

**Primary key:** composite `(tweet_id, hashtag_id)`
**Indexes:** `ix_tweethashtag_hashtag` on `hashtag_id`

> No `created_at`/`updated_at` — rows are immutable once created.

### Mention

Pure join table linking tweets to mentioned users.

| Column | Type | Constraints |
|---|---|---|
| `tweet_id` | bigint | not null, FK → `Tweet.id` |
| `mentioned_user_id` | bigint | not null, FK → `User.id` |

**Primary key:** composite `(tweet_id, mentioned_user_id)`
**Indexes:** `ix_mention_user` on `mentioned_user_id` — supports "tweets mentioning me" lookups

> No `created_at`/`updated_at`.

---

## App: `notifications`

### Notification

Single table backing the activity/notifications feed.

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | bigint | PK, increment | |
| `recipient_id` | bigint | not null, FK → `User.id` | Who receives the notification |
| `actor_id` | bigint | not null, FK → `User.id` | Who triggered it |
| `type` | varchar(20) | not null | Enum-like: `LIKE` \| `RETWEET` \| `FOLLOW` \| `REPLY` \| `MENTION` |
| `target_tweet_id` | bigint | FK → `Tweet.id` | Nullable — not all notification types reference a tweet (e.g. `FOLLOW`) |
| `is_read` | boolean | not null, default `false` | |
| `created_at` | timestamp | not null, default `now()` | |

**Indexes**

| Name | Columns | Purpose |
|---|---|---|
| `ix_notification_inbox` | `(recipient_id, is_read)` | Unread-count / inbox filtering |
| `ix_notification_recent` | `(recipient_id, created_at)` | Reverse-chronological feed |

> Field named `type` rather than `verb` to map cleanly onto a Django `choices` enum field.

---

## Entity Relationship Summary

```
User ──┬──< Follow.follower_id
       ├──< Follow.following_id
       ├──< Tweet.author_id
       ├──< Media (via Tweet)
       ├──< Like.user_id
       ├──< Bookmark.user_id
       ├──< Mention.mentioned_user_id
       ├──< Notification.recipient_id
       └──< Notification.actor_id

Tweet ──┬──< Tweet.parent_id       (self-referential: replies)
        ├──< Tweet.retweet_of_id  (self-referential: retweets)
        ├──< Media.tweet_id
        ├──< Like.tweet_id
        ├──< Bookmark.tweet_id
        ├──< TweetHashtag.tweet_id
        ├──< Mention.tweet_id
        └──< Notification.target_tweet_id

Hashtag ──< TweetHashtag.hashtag_id
```

`<` denotes "one-to-many, read as the many side."

---

## Design Decisions

| Decision | Rationale |
|---|---|
| Retweets as self-referential `Tweet` rows | Avoids a `UNION` across a separate `Retweet` table when building timelines |
| Soft delete (`deleted_at`) on `Tweet` | Preserves reply threads; deleted parents can render a placeholder instead of orphaning children |
| No stored engagement counts (`like_count`, etc.) | Avoids write-time denormalization complexity for this project's scope; computed at read time instead. See `docs/Decisions.md` |
| `Media` as its own table | Supports multiple images/video per tweet without a future schema migration |
| `Hashtag`/`Mention` as separate join tables rather than array columns | Keeps referential integrity and indexable lookups (e.g. "tweets mentioning me," "tweets tagged #x") |
| `display_name` mutable and non-unique, `username` unique | Mirrors X's actual handle vs. display-name distinction |

---

