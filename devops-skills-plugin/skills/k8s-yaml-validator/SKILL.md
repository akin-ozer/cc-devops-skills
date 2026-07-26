---
name: k8s-yaml-validator
description: "Use when linting, schema-checking, security-reviewing, or dry-run validating Kubernetes manifests and custom resources."
---

# Kubernetes YAML Validator

## Purpose

Produce a report-only Kubernetes manifest review covering YAML, schemas, API compatibility, security, and optional dry-run behavior. Do not modify files unless the user separately asks for fixes.

## Workflow

1. Resolve target files, intended Kubernetes version, and whether cluster access is permitted.
2. Count and parse all YAML documents, then run available schema and policy checks.
3. Detect CRDs with `scripts/detect_crd_wrapper.sh`; consult authoritative version-matched schemas for detected custom resources.
4. Use focused references only for actual findings; open `references/extended-guide.md` for the full validation matrix.
5. Report suggested corrections as examples and keep blocked, skipped, and passing checks distinct.

## Resources

- `scripts/count_yaml_documents.py`: multi-document coverage
- `scripts/detect_crd_wrapper.sh`: custom-resource discovery
- `references/`: validation, security, and CRD guidance
- `references/extended-guide.md`: complete command and report workflow

## Safety and gotchas

- Default to offline/static checks and client dry-run. Server dry-run contacts the configured cluster and requires authorization.
- Confirm context and namespace before any cluster-backed check.
- Redact Secret data and sensitive annotations.
- A missing CRD schema is unknown coverage, not a valid resource.

## Validation

Run the document counter tests and available fixture checks. Record Kubernetes version, schema source, CRD coverage, kubectl mode, and unavailable tools.

## Output

Report findings by severity and file/document location, suggested fixes, validation coverage, and skipped/blocked checks. Do not offer or apply edits in this workflow.
