-- ==============================================================================
-- MultiSynk: Household-based sync schema
-- Run this ONCE on the Supabase SQL Editor:
--   Dashboard > SQL Editor > New Query > paste > Run
-- ==============================================================================

BEGIN;

-- ── 1. Rename old per-user tables ────────────────────────────────────────────
ALTER TABLE IF EXISTS transactions      RENAME TO transactions_legacy_v1;
ALTER TABLE IF EXISTS vehicles          RENAME TO vehicles_legacy_v1;
ALTER TABLE IF EXISTS maintenance_items RENAME TO maintenance_items_legacy_v1;
ALTER TABLE IF EXISTS tasks             RENAME TO tasks_legacy_v1;
ALTER TABLE IF EXISTS receivables       RENAME TO receivables_legacy_v1;
ALTER TABLE IF EXISTS fiorino_entries   RENAME TO fiorino_entries_legacy_v1;
ALTER TABLE IF EXISTS fiorino_config    RENAME TO fiorino_config_legacy_v1;
ALTER TABLE IF EXISTS studio_entries    RENAME TO studio_entries_legacy_v1;
ALTER TABLE IF EXISTS studio_config     RENAME TO studio_config_legacy_v1;
ALTER TABLE IF EXISTS fixed_expenses    RENAME TO fixed_expenses_legacy_v1;
ALTER TABLE IF EXISTS payment_cards     RENAME TO payment_cards_legacy_v1;
ALTER TABLE IF EXISTS shopping_items    RENAME TO shopping_items_legacy_v1;

-- ── 2. Households ────────────────────────────────────────────────────────────
CREATE TABLE households (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL DEFAULT 'Nossa Casa',
  invite_code text UNIQUE NOT NULL DEFAULT upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE household_members (
  household_id uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role         text NOT NULL DEFAULT 'member',
  joined_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (household_id, user_id)
);

ALTER TABLE households        ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_members ENABLE ROW LEVEL SECURITY;

-- Helper: is caller a member of household h?
CREATE OR REPLACE FUNCTION is_member(h uuid) RETURNS boolean
  LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT EXISTS (
    SELECT 1 FROM household_members WHERE household_id = h AND user_id = auth.uid()
  )
$$;

CREATE POLICY "members see household" ON households
  FOR ALL USING (is_member(id));

CREATE POLICY "members see fellow members" ON household_members
  FOR ALL USING (is_member(household_id));

-- ── 3. RPC functions ─────────────────────────────────────────────────────────

-- ensure_household: returns the caller's household (creates one if needed)
CREATE OR REPLACE FUNCTION ensure_household()
  RETURNS SETOF households
  LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  hid uuid;
BEGIN
  SELECT household_id INTO hid FROM household_members WHERE user_id = auth.uid() LIMIT 1;
  IF hid IS NULL THEN
    INSERT INTO households DEFAULT VALUES RETURNING id INTO hid;
    INSERT INTO household_members (household_id, user_id, role) VALUES (hid, auth.uid(), 'owner');
  END IF;
  RETURN QUERY SELECT * FROM households WHERE id = hid;
END
$$;

-- join_household: joins the caller to an existing household by invite code
CREATE OR REPLACE FUNCTION join_household(p_code text)
  RETURNS SETOF households
  LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  hid uuid;
  old_hid uuid;
BEGIN
  SELECT id INTO hid FROM households WHERE invite_code = upper(trim(p_code));
  IF hid IS NULL THEN RAISE EXCEPTION 'invalid_code'; END IF;

  SELECT household_id INTO old_hid FROM household_members WHERE user_id = auth.uid();
  IF old_hid IS NOT NULL AND old_hid <> hid THEN
    DELETE FROM household_members WHERE user_id = auth.uid() AND household_id = old_hid;
    -- Clean up empty household
    IF NOT EXISTS (SELECT 1 FROM household_members WHERE household_id = old_hid) THEN
      DELETE FROM households WHERE id = old_hid;
    END IF;
  END IF;

  INSERT INTO household_members (household_id, user_id, role)
    VALUES (hid, auth.uid(), 'member')
    ON CONFLICT DO NOTHING;

  RETURN QUERY SELECT * FROM households WHERE id = hid;
END
$$;

-- household_members_list: returns members of the caller's household
CREATE OR REPLACE FUNCTION household_members_list()
  RETURNS TABLE (email text, role text)
  LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  hid uuid;
BEGIN
  SELECT household_id INTO hid FROM household_members WHERE user_id = auth.uid() LIMIT 1;
  RETURN QUERY
    SELECT u.email::text, hm.role
    FROM household_members hm
    JOIN auth.users u ON u.id = hm.user_id
    WHERE hm.household_id = hid;
END
$$;

-- ── 4. Sync row guard (trigger) ──────────────────────────────────────────────
CREATE SEQUENCE IF NOT EXISTS sync_seq_counter;

CREATE OR REPLACE FUNCTION sync_row_guard() RETURNS trigger
  LANGUAGE plpgsql AS $$
BEGIN
  -- Last-write-wins: reject if the incoming updated_at is older
  IF TG_OP = 'UPDATE' AND NEW.updated_at < OLD.updated_at THEN
    RETURN OLD;
  END IF;
  NEW.sync_seq   := nextval('sync_seq_counter');
  NEW.updated_by := auth.uid();
  RETURN NEW;
END
$$;

-- ── 5. Data tables ───────────────────────────────────────────────────────────

CREATE TABLE transactions (
  household_id       uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  id                 text NOT NULL,
  description        text NOT NULL,
  amount             real NOT NULL,
  type               text NOT NULL,
  date               text NOT NULL,
  category           text,
  vehicle_id         text,
  payment_method     text,
  card_id            text,
  installments       integer NOT NULL DEFAULT 1,
  installment_number integer NOT NULL DEFAULT 1,
  installment_group_id text,
  updated_at         bigint NOT NULL DEFAULT 0,
  deleted            boolean NOT NULL DEFAULT false,
  updated_by         uuid,
  sync_seq           bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, id)
);

CREATE TABLE vehicles (
  household_id uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  id           text NOT NULL,
  name         text NOT NULL,
  brand        text NOT NULL,
  model        text NOT NULL,
  color        text NOT NULL,
  plate        text,
  year         integer,
  notes        text,
  updated_at   bigint NOT NULL DEFAULT 0,
  deleted      boolean NOT NULL DEFAULT false,
  updated_by   uuid,
  sync_seq     bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, id)
);

CREATE TABLE maintenance_items (
  household_id   uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  id             text NOT NULL,
  vehicle_id     text NOT NULL,
  title          text NOT NULL,
  description    text,
  priority       text NOT NULL DEFAULT 'normal',
  due_date       text,
  estimated_cost real,
  is_done        integer NOT NULL DEFAULT 0,
  updated_at     bigint NOT NULL DEFAULT 0,
  deleted        boolean NOT NULL DEFAULT false,
  updated_by     uuid,
  sync_seq       bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, id)
);

CREATE TABLE tasks (
  household_id uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  id           text NOT NULL,
  title        text NOT NULL,
  description  text,
  priority     text NOT NULL DEFAULT 'none',
  ai_priority  text,
  ai_reason    text,
  category     text NOT NULL DEFAULT 'personal',
  created_at   text NOT NULL,
  due_date     text,
  is_done      integer NOT NULL DEFAULT 0,
  updated_at   bigint NOT NULL DEFAULT 0,
  deleted      boolean NOT NULL DEFAULT false,
  updated_by   uuid,
  sync_seq     bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, id)
);

CREATE TABLE receivables (
  household_id    uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  id              text NOT NULL,
  description     text NOT NULL,
  expected_amount real NOT NULL,
  received_amount real,
  expected_date   text NOT NULL,
  status          text NOT NULL DEFAULT 'pending',
  is_recurring    integer NOT NULL DEFAULT 0,
  updated_at      bigint NOT NULL DEFAULT 0,
  deleted         boolean NOT NULL DEFAULT false,
  updated_by      uuid,
  sync_seq        bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, id)
);

CREATE TABLE fiorino_entries (
  household_id       uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  id                 text NOT NULL,
  amount             real NOT NULL,
  date               text NOT NULL,
  notes              text,
  safety_percent     real NOT NULL DEFAULT 0.10,
  maintenance_percent real NOT NULL DEFAULT 0.10,
  fuel_percent       real NOT NULL DEFAULT 0.20,
  updated_at         bigint NOT NULL DEFAULT 0,
  deleted            boolean NOT NULL DEFAULT false,
  updated_by         uuid,
  sync_seq           bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, id)
);

CREATE TABLE fiorino_config (
  household_id       uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  key                text NOT NULL,
  safety_percent     real NOT NULL DEFAULT 0.10,
  maintenance_percent real NOT NULL DEFAULT 0.10,
  fuel_percent       real NOT NULL DEFAULT 0.20,
  updated_at         bigint NOT NULL DEFAULT 0,
  deleted            boolean NOT NULL DEFAULT false,
  updated_by         uuid,
  sync_seq           bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, key)
);

CREATE TABLE studio_entries (
  household_id       uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  id                 text NOT NULL,
  amount             real NOT NULL,
  type               text NOT NULL,
  description        text NOT NULL,
  category           text,
  date               text NOT NULL,
  notes              text,
  payment_method     text,
  card_id            text,
  installments       integer NOT NULL DEFAULT 1,
  installment_number integer NOT NULL DEFAULT 1,
  installment_group_id text,
  updated_at         bigint NOT NULL DEFAULT 0,
  deleted            boolean NOT NULL DEFAULT false,
  updated_by         uuid,
  sync_seq           bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, id)
);

CREATE TABLE studio_config (
  household_id    uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  key             text NOT NULL,
  safety_percent  real NOT NULL DEFAULT 0.10,
  savings_percent real NOT NULL DEFAULT 0.15,
  updated_at      bigint NOT NULL DEFAULT 0,
  deleted         boolean NOT NULL DEFAULT false,
  updated_by      uuid,
  sync_seq        bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, key)
);

CREATE TABLE fixed_expenses (
  household_id uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  id           text NOT NULL,
  description  text NOT NULL,
  amount       real NOT NULL,
  category     text NOT NULL DEFAULT '',
  scope        text NOT NULL DEFAULT 'personal',
  is_active    integer NOT NULL DEFAULT 1,
  due_day      integer NOT NULL DEFAULT 10,
  updated_at   bigint NOT NULL DEFAULT 0,
  deleted      boolean NOT NULL DEFAULT false,
  updated_by   uuid,
  sync_seq     bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, id)
);

CREATE TABLE payment_cards (
  household_id uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  id           text NOT NULL,
  name         text NOT NULL,
  last_four    text,
  closing_day  integer NOT NULL DEFAULT 1,
  due_day      integer NOT NULL DEFAULT 10,
  color        text NOT NULL DEFAULT '#7C3AED',
  updated_at   bigint NOT NULL DEFAULT 0,
  deleted      boolean NOT NULL DEFAULT false,
  updated_by   uuid,
  sync_seq     bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, id)
);

CREATE TABLE shopping_items (
  household_id   uuid NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  id             text NOT NULL,
  description    text NOT NULL,
  quantity       integer NOT NULL DEFAULT 1,
  estimated_price real,
  category       text NOT NULL DEFAULT 'outro',
  is_purchased   integer NOT NULL DEFAULT 0,
  ai_priority    text,
  ai_reason      text,
  created_at     text NOT NULL,
  updated_at     bigint NOT NULL DEFAULT 0,
  deleted        boolean NOT NULL DEFAULT false,
  updated_by     uuid,
  sync_seq       bigint NOT NULL DEFAULT 0,
  PRIMARY KEY (household_id, id)
);

-- ── 6. RLS + triggers on every data table ────────────────────────────────────
DO $$
DECLARE
  t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'transactions', 'vehicles', 'maintenance_items', 'tasks', 'receivables',
    'fiorino_entries', 'fiorino_config', 'studio_entries', 'studio_config',
    'fixed_expenses', 'payment_cards', 'shopping_items'
  ])
  LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY "household access" ON %I FOR ALL USING (is_member(household_id)) WITH CHECK (is_member(household_id))', t);
    EXECUTE format('CREATE TRIGGER sync_guard BEFORE INSERT OR UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION sync_row_guard()', t);
    -- Index for fast pull by sync_seq
    EXECUTE format('CREATE INDEX idx_%s_sync ON %I (household_id, sync_seq)', t, t);
  END LOOP;
END
$$;

-- ── 7. Enable auto-confirm for email signups ─────────────────────────────────
-- (This is done via the Supabase auth config API, not SQL.)
-- Run in Supabase Dashboard: Authentication > Settings > Enable "Auto-confirm users"

COMMIT;
