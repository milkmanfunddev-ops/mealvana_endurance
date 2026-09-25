#!/usr/bin/env python3
"""raw-retention vector runner (real-payload-corpus@v1).

Drives public.raw_retention_sweep(p_now) — the REAL migrated function — at the
vectors' synthetic clocks. Day arithmetic: day N = BASE + N days; every insert
goes through the repository's write semantics (INSERT .. ON CONFLICT DO
NOTHING against the versioning unique constraint), because "a re-fetch with an
unchanged LastModifiedDate writes nothing" is a property of that write path,
not of the sweep.

Env: DB_URL, VECTORS. Uses psql (no python pg driver dependency).
"""
import json
import os
import subprocess
import sys

DB_URL = os.environ["DB_URL"]
VECTORS = os.environ["VECTORS"]
BASE = "2026-01-01T00:00:00Z"
USER = "00000000-0000-0000-0000-000000000001"


def sql(query: str) -> str:
    res = subprocess.run(
        ["psql", DB_URL, "-v", "ON_ERROR_STOP=1", "-qtAX", "-c", query],
        capture_output=True, text=True,
    )
    if res.returncode != 0:
        print(res.stderr, file=sys.stderr)
        sys.exit(2)
    return res.stdout.strip()


def day(n: int) -> str:
    return f"(TIMESTAMPTZ '{BASE}' + INTERVAL '{n} days')"


def main() -> None:
    vectors = json.load(open(VECTORS))["vectors"]
    failures = []
    for v in vectors:
        sql("TRUNCATE public.provider_raw_payloads, public.raw_retention_audit,"
            " public.expected_flows")
        for ev in v["inputs"]["syncEvents"]:
            sql(
                "INSERT INTO public.provider_raw_payloads "
                "(user_id, provider, provider_workout_id, last_modified, "
                " fetched_at, data) VALUES "
                f"('{USER}', 'training_peaks', '{ev['workoutId']}', "
                f"'{ev['lastModified']}', {day(ev['fetchedDay'])}, "
                "'{}'::jsonb) "
                "ON CONFLICT ON CONSTRAINT provider_raw_payloads_version_key "
                "DO NOTHING"
            )
        sql(f"SELECT public.raw_retention_sweep({day(v['inputs']['nowDay'])})")
        rows = sql(
            "SELECT provider_workout_id, last_modified, "
            f"round(extract(epoch FROM (fetched_at - TIMESTAMPTZ '{BASE}')) "
            "/ 86400)::int "
            "FROM public.provider_raw_payloads ORDER BY 1, 2, 3"
        )
        got = sorted(
            (a, b, int(c))
            for a, b, c in (line.split("|") for line in rows.splitlines() if line)
        )
        want = sorted(
            (r["workoutId"], r["lastModified"], r["fetchedDay"])
            for r in v["expected"]["survivingRows"]
        )
        status = "PASS" if got == want else "FAIL"
        print(f"   vector:  {v['id']}: {status}")
        if got != want:
            failures.append((v["id"], want, got))

    if failures:
        for vid, want, got in failures:
            print(f"FAIL {vid}\n  want {want}\n  got  {got}", file=sys.stderr)
        sys.exit(1)
    print(f"   raw-retention: {len(vectors)} vectors green ✓")




def di19_both_alerts() -> bool:
    """DI-19: seeded expected_flows + injected clock -> BOTH alert paths fire.

    Sequence: an armed flow (first-ever row seen on an earlier sweep), its
    precondition held (active integration row), zero rows inside the window at
    a later sweep, and a tiny plan-bytes so over-size trips on the same run.
    Also asserts the arming sweep itself did NOT alert (an unarmed flow never
    alerts, even on the sweep that arms it).
    """
    sql("TRUNCATE public.provider_raw_payloads, public.raw_retention_audit,"
        " public.expected_flows, public.integrations")
    sql("INSERT INTO public.integrations (provider, is_active)"
        " VALUES ('training_peaks', true)")
    sql("INSERT INTO public.provider_raw_payloads (user_id, provider,"
        f" provider_workout_id, last_modified, fetched_at, data) VALUES"
        f" ('{USER}', 'training_peaks', 'W1', 'T1', {day(0)}, '{{}}'::jsonb)")
    sql("INSERT INTO public.expected_flows (flow, source_table, source_filter,"
        " precondition, min_rows, window_interval) VALUES"
        " ('tp_raw_arrival', 'provider_raw_payloads', 'training_peaks',"
        "  'active_integration:training_peaks', 1, INTERVAL '7 days')")
    # Sweep 1 (day 1): arms the flow; must NOT alert.
    arming = sql(
        "SELECT (underarrival_alerts = '[]'::jsonb) AND NOT oversize_alert"
        f" FROM public.raw_retention_sweep({day(1)})")
    armed = sql("SELECT armed_at IS NOT NULL FROM public.expected_flows"
                " WHERE flow = 'tp_raw_arrival'")
    # Sweep 2 (day 30, 1KB 'plan'): window empty + precondition held ->
    # under-arrival; tiny plan -> over-size. Both on one audit row.
    both = sql(
        "SELECT oversize_alert AND underarrival_alerts ? 'tp_raw_arrival'"
        f" FROM public.raw_retention_sweep({day(30)}, 1024)")
    ok = arming == "t" and armed == "t" and both == "t"
    print(f"   di-19:   arming-sweep-silent={arming} armed={armed} "
          f"both-alerts-fire={both}: {'PASS' if ok else 'FAIL'}")
    return ok


if __name__ == "__main__":
    main()
    if not di19_both_alerts():
        sys.exit(1)
