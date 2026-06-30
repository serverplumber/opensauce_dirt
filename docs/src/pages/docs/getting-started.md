---
layout: ../../layouts/DocsLayout.astro
title: Development Setup
description: Set up a local development environment for contributing to OpenSauce
---

## Prerequisites

Before setting up OpenSauce, make sure you have the following installed:

- **Elixir** 1.18 or later
- **Erlang/OTP** 25 or later
- **PostgreSQL** 16 or later
- **Node.js** 18 or later (for asset building)
- **Docker** and **Docker Compose** (recommended for running PostgreSQL and MinIO)

## Starting Dependencies

The easiest way to run PostgreSQL and MinIO (S3-compatible object storage) is with Docker Compose:

```bash
docker-compose up -d
```

This starts PostgreSQL 16 on the default port and MinIO for file storage.

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/serverplumber/opensauce_dirt.git
   cd opensauce_dirt
   ```

2. Run the full setup (installs deps, runs migrations, builds assets, seeds data):

   ```bash
   mix setup
   ```

   This single command handles `mix deps.get`, `mix ash.setup`, asset installation, and database seeding.

3. Start the Phoenix development server:

   ```bash
   mix phx.server
   ```

4. Open [localhost:4000](http://localhost:4000) in your browser.

## Dev Accounts

The seed data creates three accounts in the **Plants Plan Designs Inc.** demo organisation:

| Email | Role |
|-------|------|
| `admin@sauce` | Owner |
| `owner@sauce` | Owner |
| `staff@sauce` | Staff |

Authentication uses **magic links** — there are no passwords. On the sign-in page, enter one of the emails above and submit. The link is printed directly to your server terminal (stdout) rather than sent by email:

```
┌─ MAGIC LINK ──────────────────────────────────────────────────┐
│  http://localhost:4000/auth/user/magic_link?token=...
└───────────────────────────────────────────────────────────────┘
```

Copy and paste the URL into your browser to sign in.

> **Note:** If you change seed accounts and re-seed without a full `mix ash.reset`, stale token records can cause magic links to silently fail (no link printed, no error shown). `mix ash.reset` is the fix.

## Common Commands

| Command | Purpose |
|---------|---------|
| `mix setup` | Full setup: deps, migrations, assets, seeds |
| `mix phx.server` | Start the dev server |
| `mix test` | Run the test suite |
| `mix test path/to/test.exs` | Run a single test file |
| `mix test path/to/test.exs:42` | Run a specific test at a line |
| `mix format` | Format all code (Elixir, Tailwind, HEEx) |
| `mix dialyzer` | Static type analysis |
| `mix ash.setup` | Run migrations and Ash introspection |
| `mix ash.reset` | Drop, create, migrate, and seed the database |

## What's Next

After signing in, you land on **Manage → Overview**. Read the [Overview & Planner](/opensauce/docs/overview/) guide to learn how the main workspace is organized.
