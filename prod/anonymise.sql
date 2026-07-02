-- Anonymise all PII in place.
-- Safe to run multiple times. Run after restoring a prod backup to preprod or dev.
-- Does not touch org name — preserves context for developers.

BEGIN;

-- ── Customers ────────────────────────────────────────────────────────────────
UPDATE crm_customers
SET
  first_name            = 'First' || n.rn,
  last_name             = 'Last'  || n.rn,
  company_name_nickname = CASE WHEN company_name_nickname IS NOT NULL
                               THEN 'Company ' || n.rn END,
  email                 = CASE WHEN email IS NOT NULL
                               THEN 'customer' || n.rn || '@example.com' END,
  phone                 = CASE WHEN phone IS NOT NULL
                               THEN '(555) 010-' || lpad(n.rn::text, 4, '0') END
FROM (
  SELECT id, row_number() OVER (ORDER BY id) AS rn
  FROM crm_customers
) n
WHERE crm_customers.id = n.id;

-- ── Addresses (garden sites + billing) ───────────────────────────────────────
UPDATE crm_addresses
SET
  name     = CASE WHEN name IS NOT NULL THEN 'Site ' || n.rn END,
  street   = '123 Test Street',
  city     = 'Test City',
  province = 'ON',
  zip      = 'A1A 1A1',
  notes    = NULL,
  location = NULL
FROM (
  SELECT id, row_number() OVER (ORDER BY id) AS rn
  FROM crm_addresses
) n
WHERE crm_addresses.id = n.id;

-- ── Users (staff accounts) ────────────────────────────────────────────────────
UPDATE accounts_users
SET
  first_name = 'Staff',
  last_name  = n.rn::text,
  email      = 'staff' || n.rn || '@example.com'
FROM (
  SELECT id, row_number() OVER (ORDER BY id) AS rn
  FROM accounts_users
) n
WHERE accounts_users.id = n.id;

-- ── Organisations (contact + payment details only, name preserved) ────────────
UPDATE accounts_organisations
SET
  phone              = NULL,
  website            = NULL,
  email_from_address = 'noreply@example.com',
  payment_info       = NULL,
  contact_name       = NULL,
  contact_phone      = NULL,
  contact_email      = NULL;

-- ── Auth tokens (all invalid after a data move) ───────────────────────────────
TRUNCATE accounts_tokens;

COMMIT;
