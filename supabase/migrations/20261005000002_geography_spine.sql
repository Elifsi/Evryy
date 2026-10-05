-- =============================================================================
-- 0002 — Nepal administrative spine
-- Source: bibekoli/local-levels-of-nepal-dataset
--   7 provinces · 77 districts · 753 local levels (+ 4 local-level types)
-- Every physical entity references local_levels(id). Rows are loaded by 0011.
-- =============================================================================

CREATE TABLE public.provinces (
  id          SMALLINT PRIMARY KEY,
  name        TEXT NOT NULL,
  nepali_name TEXT NOT NULL
);

CREATE TABLE public.districts (
  id          SMALLINT PRIMARY KEY,
  province_id SMALLINT NOT NULL REFERENCES public.provinces(id),
  name        TEXT NOT NULL,
  nepali_name TEXT NOT NULL
);
CREATE INDEX districts_province_idx ON public.districts (province_id);

CREATE TABLE public.local_level_types (
  id          SMALLINT PRIMARY KEY,
  name        TEXT NOT NULL,
  nepali_name TEXT NOT NULL
);

CREATE TABLE public.local_levels (
  id            SMALLINT PRIMARY KEY,
  district_id   SMALLINT NOT NULL REFERENCES public.districts(id),
  type_id       SMALLINT NOT NULL REFERENCES public.local_level_types(id),
  name          TEXT NOT NULL,
  nepali_name   TEXT NOT NULL,
  -- Number of wards is not in the source dataset; ward_no on entities is
  -- validated as 1..35 (largest metropolitan city has 32 wards).
  CONSTRAINT local_levels_name_district_uniq UNIQUE (district_id, name)
);
CREATE INDEX local_levels_district_idx ON public.local_levels (district_id);
CREATE INDEX local_levels_name_trgm_idx ON public.local_levels USING gin (name extensions.gin_trgm_ops);

-- Reference data: world-readable, writable only by migrations / service role.
ALTER TABLE public.provinces         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.districts         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.local_level_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.local_levels      ENABLE ROW LEVEL SECURITY;

CREATE POLICY provinces_read         ON public.provinces         FOR SELECT USING (true);
CREATE POLICY districts_read         ON public.districts         FOR SELECT USING (true);
CREATE POLICY local_level_types_read ON public.local_level_types FOR SELECT USING (true);
CREATE POLICY local_levels_read      ON public.local_levels      FOR SELECT USING (true);
