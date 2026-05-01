---
layout: ../../layouts/DocsLayout.astro
title: Introduction
---

OpenSauce is an open-source ERP for small-scale manufacturers — bakeries,
fermenters, food producers, and similar operations where production is
recipe-driven and inventory is consumed in batches.

It is a complete rewrite of Craftplan, built on:

- [Ash Framework](https://ash-hq.org) — domain modelling and business logic
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) — real-time UI
- PostgreSQL 16

## Domains

| Domain | Responsibility |
|---|---|
| `Accounts` | Users, authentication, API keys |
| `Catalog` | Products, BOMs, labor steps, rollups |
| `Orders` | Orders, order items, production batches |
| `Inventory` | Materials, lots, movements, forecasting |
| `CRM` | Customers, suppliers |
| `Settings` | App-wide configuration |

## Quick start

```bash
git clone https://github.com/serverplumber/opensauce
cd opensauce
cp .env.example .env
docker compose up -d
mix setup
mix phx.server
```

Visit `localhost:4000`.
