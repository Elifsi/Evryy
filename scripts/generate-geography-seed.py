#!/usr/bin/env python3
"""Generate supabase/migrations/20261005000011_seed_nepal_geography.sql from the
bibekoli/local-levels-of-nepal-dataset JSON files (cloned into reference/ by
`reference/sync.sh nepal`). The generated SQL is committed so deployments never
depend on the reference/ checkout.

Usage:  python3 scripts/generate-geography-seed.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "reference" / "bibekoli_local-levels-of-nepal-dataset"
OUT = ROOT / "supabase" / "migrations" / "20261005000011_seed_nepal_geography.sql"


def q(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def load(name):
    return json.loads((SRC / f"{name}.json").read_text(encoding="utf-8"))


provinces = sorted(load("provinces"), key=lambda r: r["province_id"])
districts = sorted(load("districts"), key=lambda r: r["district_id"])
types = sorted(load("local_level_type"), key=lambda r: r["local_level_type_id"])
levels = sorted(load("local_levels"), key=lambda r: r["municipality_id"])

assert len(provinces) == 7, len(provinces)
assert len(districts) == 77, len(districts)
assert len(levels) == 753, len(levels)

lines = [
    "-- =============================================================================",
    "-- 0011 — Seed: Nepal administrative spine (GENERATED FILE — do not edit by hand)",
    "-- Source: bibekoli/local-levels-of-nepal-dataset",
    "-- Regenerate with: python3 scripts/generate-geography-seed.py",
    f"-- {len(provinces)} provinces · {len(districts)} districts · {len(levels)} local levels",
    "-- =============================================================================",
    "",
    "INSERT INTO public.provinces (id, name, nepali_name) VALUES",
    ",\n".join(f"  ({p['province_id']}, {q(p['name'])}, {q(p['nepali_name'])})" for p in provinces),
    "ON CONFLICT (id) DO NOTHING;",
    "",
    "INSERT INTO public.districts (id, province_id, name, nepali_name) VALUES",
    ",\n".join(f"  ({d['district_id']}, {d['province_id']}, {q(d['name'])}, {q(d['nepali_name'])})" for d in districts),
    "ON CONFLICT (id) DO NOTHING;",
    "",
    "INSERT INTO public.local_level_types (id, name, nepali_name) VALUES",
    ",\n".join(f"  ({t['local_level_type_id']}, {q(t['name'])}, {q(t['nepali_name'])})" for t in types),
    "ON CONFLICT (id) DO NOTHING;",
    "",
    "INSERT INTO public.local_levels (id, district_id, type_id, name, nepali_name) VALUES",
    ",\n".join(
        f"  ({l['municipality_id']}, {l['district_id']}, {l['local_level_type_id']}, {q(l['name'])}, {q(l['nepali_name'])})"
        for l in levels
    ),
    "ON CONFLICT (id) DO NOTHING;",
    "",
]
OUT.write_text("\n".join(lines), encoding="utf-8")
print(f"wrote {OUT.relative_to(ROOT)}: {len(provinces)} provinces, {len(districts)} districts, {len(levels)} local levels")
