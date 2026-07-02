---
layout: ../../layouts/DocsLayout.astro
title: Introduction
---

Dirt is an open-source ERP for small landscaping and gardening businesses — covering client engagement management, field job scheduling, crew costing, materials purchasing, and invoicing.

It is built on:

- [Ash Framework](https://ash-hq.org) — domain modelling and business logic
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) — real-time mobile UI
- PostgreSQL 16

## Feature guides

- **Customers & Engagements** — Client records, garden sites, scope proposals, and client signing
- **Jobs & Scheduling** — Job types (client work, shifts, internal), crew assignment, calendar
- **Inventory** — Materials, lots, movements, supplier catalogues
- **Purchasing** — Suppliers, purchase orders, receiving
- **Invoicing & Costing** — Invoice lifecycle, line items, tax, realized cost

## Architecture

- **[Domain Architecture](/docs/domains/)** — Ash domains, tenancy model, auth flow
- **[Data Model & Calculations](/docs/data-model/)** — Entity relationships and how costs and totals are computed
