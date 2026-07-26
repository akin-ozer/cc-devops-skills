---
name: loki-config-generator
description: "Use when creating or updating Grafana Loki server configuration, deployment modes, storage backends, tenancy, ruler, TLS, or Alloy ingestion."
---

# Loki Configuration Generator

## Purpose

Generate a coherent Loki configuration for the chosen topology, storage, retention, and tenancy model.

## Workflow

1. Determine Loki version, deployment mode, expected scale, storage backend, schema history, retention, tenancy, ruler, TLS, and deployment platform.
2. Clarify choices that affect data durability or compatibility; do not invent cloud bucket, credential, or endpoint values.
3. Use `scripts/generate_config.py` for supported modes or adapt the closest `examples/` file. Read `loki_config_reference.md` and `best_practices.md` only as needed; open `extended-guide.md` for advanced combinations.
4. Generate config plus any required values or Alloy fragments with externalized secrets.
5. Validate structure and component consistency, then run repository tests.

## Resources

- `scripts/generate_config.py`: supported topology/storage generator
- `examples/`: monolithic, scalable, microservices, storage, TLS, ruler, tenancy, and Alloy patterns
- `references/loki_config_reference.md`, `best_practices.md`: focused settings
- `references/extended-guide.md`: comprehensive workflow

## Safety and gotchas

- Never embed cloud credentials, tenant tokens, or TLS private keys.
- Preserve existing schema periods when upgrading; incorrect `schema_config` can make historical data unreadable.
- Match replication and ring configuration to the actual topology.
- Prefer Grafana Alloy over deprecated Promtail for new ingestion setups.
- Do not deploy or restart Loki while generating files.

## Validation

Run `python3 scripts/test_generate_config.py` and relevant parser/config checks. Mark live object-storage, ring, and runtime compatibility as unverified when unavailable.

## Output

List files, topology/schema/storage decisions, required external secrets, migration cautions, and validation evidence.
