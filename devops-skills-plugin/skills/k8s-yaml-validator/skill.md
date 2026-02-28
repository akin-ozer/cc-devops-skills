---
name: k8s-yaml-validator
description: Comprehensive toolkit for validating, linting, and testing Kubernetes YAML resources. Use this skill when validating Kubernetes manifests, debugging YAML syntax errors, performing dry-run tests on clusters, or working with Custom Resource Definitions (CRDs) that require documentation lookup.
---

# Kubernetes YAML Validator

## Overview

This skill provides a comprehensive validation workflow for Kubernetes YAML resources, combining syntax linting, schema validation, cluster dry-run testing, and intelligent CRD documentation lookup. Validate any Kubernetes manifest with confidence before applying it to the cluster.

**IMPORTANT: This is a REPORT-ONLY validation tool.** Do NOT modify files, do NOT use Edit tool, do NOT use AskUserQuestion to offer fixes. Generate a comprehensive validation report with suggested fixes shown as before/after code blocks, then let the user decide what to do next.

## Trigger Phrases

Use this skill when prompts look like:
- "Validate this Kubernetes YAML before deploy."
- "Lint these manifests and report what is broken."
- "Check this CRD manifest and explain schema issues."
- "Run dry-run checks on this manifest."
- "Find line-level errors in this multi-document YAML."

## When to Use This Skill

Invoke this skill when:
- Validating Kubernetes YAML files before applying to a cluster
- Debugging YAML syntax or formatting errors
- Working with Custom Resource Definitions (CRDs) and need documentation
- Performing dry-run tests to catch admission controller errors
- Ensuring YAML follows Kubernetes best practices
- Understanding what validation errors exist in manifests (report-only, user fixes manually)
- The user asks to "validate", "lint", "check", or "test" Kubernetes YAML files

## Read-Only Boundary (Mandatory)

This skill is strictly report-only:
- Do NOT modify any user files.
- Do NOT run Edit for fixes.
- Do NOT ask for permission to apply fixes.
- Do provide before/after snippets as suggestions in the report.

## Deterministic Path Setup

Run with explicit paths so commands are repeatable:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
SKILL_DIR="$REPO_ROOT/devops-skills-plugin/skills/k8s-yaml-validator"
TARGET_FILE="$REPO_ROOT/<relative/path/to/file.yaml>"
```

Path checks:
- If `REPO_ROOT` is empty, stop and ask for repository root.
- If `SKILL_DIR` does not exist, stop and report path mismatch.
- If `TARGET_FILE` does not exist, stop and ask for the correct file.

## Validation Workflow

Follow this sequential validation workflow. Each stage catches different types of issues:

### Stage 0: Pre-Validation Setup (Deterministic Resource Count)

Before running validators, count documents using the bundled script:

```bash
python3 "$SKILL_DIR/scripts/count_yaml_documents.py" "$TARGET_FILE"
```

Expected output (example):
```json
{
  "file": ".../manifests.yaml",
  "documents": 3,
  "separators": 2
}
```

Gate rules:
- If `documents >= 3`, load `references/validation_workflow.md` before Stage 1.
- Always include the document count in the final report summary.
- If `python3` is unavailable, use fallback:
```bash
awk 'BEGIN{d=0;seen=0} /^[[:space:]]*---[[:space:]]*$/ {if(seen){d++;seen=0}; next} /^[[:space:]]*#/ {next} NF{seen=1} END{if(seen)d++; print d}' "$TARGET_FILE"
```
and mark the count as `estimated` in the report.

### Stage 1: Tool Check

Before starting validation, verify required tools are installed:

```bash
bash "$SKILL_DIR/scripts/setup_tools.sh"
```

Required tools:
- **yamllint**: YAML syntax and style linting
- **kubeconform**: Kubernetes schema validation with CRD support
- **kubectl**: Cluster dry-run testing (optional but recommended)

If tools are missing, display installation guidance from script output and continue with available tools. Document missing tools and skipped stages in the report.

### Stage 2: YAML Syntax Validation

Validate YAML syntax and formatting using yamllint:

```bash
yamllint -c "$SKILL_DIR/assets/.yamllint" "$TARGET_FILE"
```

**Common issues caught:**
- Indentation errors (tabs vs spaces)
- Trailing whitespace
- Line length violations
- Syntax errors
- Duplicate keys

**Reporting approach:**
- Report all syntax issues with file:line references
- For fixable issues, show suggested before/after code blocks
- Continue to next validation stage to collect all issues before reporting

### Stage 3: CRD Detection and Documentation Lookup

Before schema validation, detect if the YAML contains Custom Resource Definitions:

```bash
bash "$SKILL_DIR/scripts/detect_crd_wrapper.sh" "$TARGET_FILE"
```

The wrapper script automatically handles Python dependencies by creating a temporary virtual environment if PyYAML is not available.

**Resilient Parsing:** The script is resilient to syntax errors in individual documents. If a multi-document YAML file has some valid and some invalid documents, the script will:
- Parse valid documents and detect their CRDs
- Report errors for invalid documents but continue processing
- This matches kubeconform's behavior of validating 2/3 resources even when 1/3 has syntax errors

The script outputs JSON with resource information and parse status:
```json
{
  "resources": [
    {
      "kind": "Certificate",
      "apiVersion": "cert-manager.io/v1",
      "group": "cert-manager.io",
      "version": "v1",
      "isCRD": true,
      "name": "example-cert"
    }
  ],
  "parseErrors": [
    {
      "document": 1,
      "start_line": 2,
      "error_line": 6,
      "error": "mapping values are not allowed in this context"
    }
  ],
  "summary": {
    "totalDocuments": 3,
    "parsedSuccessfully": 2,
    "parseErrors": 1,
    "crdsDetected": 1
  }
}
```

**For each detected CRD:**

1. **Try Context7 MCP first (preferred):**
   - Resolve library:
     - Tool: `mcp__context7__resolve-library-id`
     - `libraryName`: CRD project name (example: `cert-manager` for `cert-manager.io`)
   - Query docs:
     - Tool: `mcp__context7__query-docs`
     - `libraryId`: resolved library ID from previous step
     - `query`: include CRD kind, group, and version (example: `Certificate cert-manager.io v1 required fields in spec`)

2. **Fallback to `web.search_query` if Context7 fails or returns insufficient details:**
   ```
   Search query pattern:
   "<kind>" "<group>" kubernetes CRD "<version>" documentation spec

   Example:
   "Certificate" "cert-manager.io" kubernetes CRD "v1" documentation spec
   ```

3. **Extract key information:**
   - Required fields in `spec`
   - Field types and validation rules
   - Examples from documentation
   - Version-specific changes or deprecations

**Secondary CRD Detection via kubeconform:** If `detect_crd_wrapper.sh` cannot identify CRDs (for example, syntax errors in all documents), but kubeconform still validates a CRD resource, look up docs for that CRD anyway. Parse kubeconform output to identify validated CRDs and perform Context7/`web.search_query` lookups.

**Why this matters:** CRDs have custom schemas not available in standard Kubernetes validation tools. Understanding the CRD's spec requirements prevents validation errors and ensures correct resource configuration.

### Stage 4: Schema Validation

Validate against Kubernetes schemas using kubeconform:

```bash
kubeconform \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -strict \
  -ignore-missing-schemas \
  -summary \
  -verbose \
  "$TARGET_FILE"
```

**Options explained:**
- `-strict`: Reject unknown fields (recommended for production - catches typos)
- `-ignore-missing-schemas`: Skip validation for CRDs without available schemas
- `-kubernetes-version 1.30.0`: Validate against specific K8s version

**Common issues caught:**
- Invalid apiVersion or kind
- Missing required fields
- Wrong field types
- Invalid enum values
- Unknown fields (with -strict)

**For CRDs:** If kubeconform reports "no schema found", this is expected. Use the documentation from Stage 3 to manually validate the spec fields.

### Stage 5: Cluster Dry-Run (if available)

**IMPORTANT: Always try server-side dry-run first.** Server-side validation catches more issues than client-side because it runs through admission controllers and webhooks.

**Decision Tree:**

```
1. Try server-side dry-run first:
   kubectl apply --dry-run=server -f "$TARGET_FILE"

   └─ If SUCCESS → Use results, continue to Stage 6

   └─ If FAILS with connection error (e.g., "connection refused",
      "unable to connect", "no configuration"):
      │
      ├─ 2. Attempt client-side dry-run (best effort):
      │     kubectl apply --dry-run=client --validate=false -f "$TARGET_FILE"
      │
      │     ├─ If SUCCESS:
      │     │    Document in report: "Server-side validation skipped (no cluster access)"
      │     │
      │     └─ If FAILS with discovery/openapi error (e.g., "unable to recognize",
      │        "failed to download openapi", "couldn't get current server API group list"):
      │        Document in report: "Dry-run skipped (cluster discovery unavailable)"
      │        Continue to Stage 6
      │
      └─ If FAILS with validation error (e.g., "admission webhook denied",
         "resource quota exceeded", "invalid value"):
         └─ Record the error, continue to Stage 6

   └─ If FAILS with parse error (e.g., "error converting YAML to JSON",
      "yaml: line X: mapping values are not allowed"):
      └─ Record the error, skip client-side dry-run (same error will occur)
         Document in report: "Dry-run blocked by YAML syntax errors - fix syntax first"
         Continue to Stage 6
```

**Note:** Parse errors from earlier stages (yamllint, kubeconform) will also cause dry-run to fail. Do NOT attempt client-side dry-run as a fallback for parse errors - it will produce the same error. Parse errors must be fixed before dry-run validation can proceed.

**Server-side dry-run catches:**
- Admission controller rejections
- Policy violations (PSP, OPA, Kyverno, etc.)
- Resource quota violations
- Missing namespaces
- Invalid ConfigMap/Secret references
- Webhook validations

**Client-side dry-run catches (fallback, when command succeeds):**
- Basic schema validation
- Required field checks
- Type validation
- **Note:** Does NOT catch admission controller or policy issues

**Document in your report which mode was used:**
- If server-side: "Full cluster validation performed"
- If client-side: "Limited validation (no cluster access) - admission policies not checked"
- If skipped: "Dry-run skipped - kubectl not available"
- If skipped after client fallback attempt: "Dry-run skipped (cluster discovery unavailable)"

**For updates to existing resources:**
```bash
kubectl diff -f "$TARGET_FILE"
```
This shows what would change, helping catch unintended modifications.

### Stage 6: Generate Detailed Validation Report (REPORT ONLY)

After completing all validation stages, generate a comprehensive report. **This is a REPORT-ONLY stage.**

**NEVER do any of the following:**
- Do NOT use the Edit tool to modify files
- Do NOT use AskUserQuestion to offer to fix issues
- Do NOT prompt the user asking if they want fixes applied
- Do NOT modify any YAML files

**ALWAYS do the following:**
- Generate a comprehensive validation report
- Show before/after code blocks as SUGGESTIONS only
- Let the user decide what to do after reviewing the report
- End with "Next Steps" for the user to take manually

1. **Summarize all issues found** across all stages in a table format:

   ```
   | Severity | Stage | Location | Issue | Suggested Fix |
   |----------|-------|----------|-------|---------------|
   | Error | Syntax | file.yaml:5 | Indentation error | Use 2 spaces |
   | Error | Schema | file.yaml:21 | Wrong type | Change to integer |
   | Warning | Best Practice | file.yaml:30 | Missing labels | Add app label |
   ```

2. **Categorize by severity:**
   - **Errors** (must fix): Syntax errors, missing required fields, dry-run failures
   - **Warnings** (should fix): Style issues, best practice violations
   - **Info** (optional): Suggestions for improvement

3. **Show before/after code blocks for each issue:**

   For every issue, display explicit before/after YAML snippets showing the suggested fix:

   ```
   **Issue 1: deployment.yaml:21 - Wrong field type (Error)**

   Current:
   ```yaml
           - containerPort: "80"
   ```

   Suggested Fix:
   ```yaml
           - containerPort: 80
   ```

   **Why:** containerPort must be an integer, not a string. Kubernetes will reject string values.
   Reference: See k8s_best_practices.md "Invalid Values" section.
   ```

4. **Provide validation summary:**

   ```
   ## Validation Report Summary

   File: deployment.yaml
   Resources Analyzed: 3 (Deployment, Service, Certificate)

   | Stage | Status | Issues Found |
   |-------|--------|--------------|
   | YAML Syntax | ❌ Failed | 2 errors |
   | CRD Detection | ✅ Passed | 1 CRD detected (Certificate) |
   | Schema Validation | ❌ Failed | 1 error |
   | Dry-Run | ❌ Failed | 1 error |

   Total Issues: 4 errors, 2 warnings

   ## Detailed Findings

   [List each issue with before/after code blocks as shown above]

   ## Next Steps

   1. Fix the 4 errors listed above (deployment will fail without these)
   2. Consider addressing the 2 warnings for best practices
   3. Re-run validation after fixes to confirm resolution
   ```

5. **Do NOT modify files** - this is a reporting tool only
   - Present all findings clearly
   - Let the user decide which fixes to apply
   - User can request fixes after reviewing the report

## Objective Stage Gates (Repeatable)

Use this table to keep stage decisions deterministic:

| Stage | Required | Command | Pass/Fail Criteria | Fallback |
|------|----------|---------|--------------------|----------|
| 0 Resource Count | Yes | `python3 "$SKILL_DIR/scripts/count_yaml_documents.py" "$TARGET_FILE"` | Pass when count output is produced and `documents` is recorded. | Use AWK estimator and mark `estimated`. |
| 1 Tool Check | Yes | `bash "$SKILL_DIR/scripts/setup_tools.sh"` | Pass when command runs and tool availability is known. | Continue with available tools and log skips. |
| 2 YAML Syntax | If `yamllint` available | `yamllint -c "$SKILL_DIR/assets/.yamllint" "$TARGET_FILE"` | Pass on exit code `0`; fail on lint errors. | Skip with explicit reason if missing binary. |
| 3 CRD Detection | If `python3` available | `bash "$SKILL_DIR/scripts/detect_crd_wrapper.sh" "$TARGET_FILE"` | Pass when JSON output includes `summary`. | Skip CRD extraction and rely on kubeconform clues. |
| 4 Schema | If `kubeconform` available | kubeconform command from Stage 4 | Pass when kubeconform reports valid resources. | Skip and record as coverage gap if missing binary. |
| 5 Dry-Run | If `kubectl` available | `kubectl apply --dry-run=server -f "$TARGET_FILE"` | Pass on successful server dry-run. | Attempt client-side fallback with `--dry-run=client --validate=false`; if discovery still fails, mark stage skipped. |
| 6 Report | Yes | Report generation | Pass when summary + per-issue snippets + next steps are provided. | No fallback; this stage is mandatory. |

## Fallback Matrix

| Constraint | Action | Report Language |
|-----------|--------|-----------------|
| `python3` unavailable | Skip `count_yaml_documents.py` and CRD parser scripts. Use AWK count only. | `Python runtime unavailable; CRD parser skipped, resource count is estimated.` |
| `yamllint` unavailable | Skip Stage 2; continue with schema/dry-run stages if available. | `YAML lint skipped because yamllint is not installed.` |
| `kubeconform` unavailable | Skip Stage 4; run lint and dry-run only. | `Schema validation skipped because kubeconform is not installed.` |
| `kubectl` unavailable | Skip Stage 5 entirely. | `Dry-run skipped because kubectl is not installed.` |
| No cluster connectivity | Run server-side first, then attempt client-side fallback with `--dry-run=client --validate=false`; if it still fails, skip dry-run and continue. | `Server-side dry-run unavailable due cluster access; client-side dry-run attempted.` |
| Client dry-run still requires discovery | Treat dry-run as unavailable and rely on lint + schema stages. | `Dry-run skipped (cluster discovery unavailable); lint and schema results used.` |
| External docs unavailable | Continue local validation and state documentation gap. | `CRD documentation lookup deferred due tooling/network limitation.` |

## Best Practices Reference

For detailed Kubernetes YAML best practices, load the reference:
```
Read "$SKILL_DIR/references/k8s_best_practices.md"
```

This reference includes:
- Metadata and label conventions
- Resource limits and requests
- Security context guidelines
- Probe configurations
- Common validation issues and fixes

**When to load (ALWAYS load in these cases):**
- Schema validation fails with type errors (e.g., string vs integer, invalid values)
- Schema validation reports missing required fields
- kubeconform reports invalid field values or unknown fields
- Dry-run fails with validation errors related to resources, probes, or security
- When explaining why a fix is needed (to provide context from best practices)

## Detailed Validation Workflow Reference

For in-depth workflow details and error handling strategies, load the reference:
```
Read "$SKILL_DIR/references/validation_workflow.md"
```

This reference includes:
- Detailed command options for each tool
- Error handling strategies
- Multi-resource file handling
- Complete workflow diagram
- Troubleshooting guide

**When to load (ALWAYS load in these cases):**
- File contains 3 or more resources (multi-document YAML)
- Validation produces errors you haven't seen before or can't immediately diagnose
- Need to understand the complete workflow for debugging
- Errors span multiple validation stages

## Working with Multiple Resources

When a YAML file contains multiple resources (separated by `---`):

1. **Validate the entire file first** with yamllint and kubeconform
2. **If errors occur, identify which resource** has issues by checking line numbers
3. **For dry-run**, the file is tested as a unit (Kubernetes processes in order)
4. **Track issues per-resource** when presenting findings to the user

### Partial Parsing Behavior

When a multi-document YAML file has some valid and some invalid documents:

**Expected behavior:**
- The CRD detection script (`detect_crd.py`) will parse valid documents and skip invalid ones
- kubeconform will validate resources it can parse and report errors for unparseable ones
- The validation report should clearly show which documents parsed and which failed

**Example scenario:**
A file with 3 documents where document 1 has a syntax error:
- Document 1 (Deployment): Syntax error at line 6
- Document 2 (Service): Valid
- Document 3 (Certificate CRD): Valid

**Expected output:**
- CRD detection: Finds Certificate CRD from document 3
- kubeconform: Reports error for document 1, validates documents 2 and 3
- Report: Shows syntax error for document 1, validation results for documents 2 and 3

**In your report:**
```
| Document | Resource | Parsing | Validation |
|----------|----------|---------|------------|
| 1 | Deployment | ❌ Syntax error (line 6) | Skipped |
| 2 | Service | ✅ Parsed | ✅ Valid |
| 3 | Certificate | ✅ Parsed | ✅ Valid |
```

**Line Number Reference Style:**
- **Always use file-absolute line numbers** (line numbers relative to the start of the entire file)
- This matches what yamllint, kubeconform, and kubectl report
- Example: If a file has 3 documents and the error is in document 2 which starts at line 35, report as "line 42" (the absolute line in the file), not "line 7" (relative to document start)
- This consistency makes it easy for users to navigate directly to the error in their editor

This ensures users get maximum validation feedback even when some documents have issues.

## Error Handling Strategies

### Tool Not Available
- Run `bash "$SKILL_DIR/scripts/setup_tools.sh"` to check availability
- Provide installation instructions
- Skip optional stages but document what was skipped
- Continue with available tools

### Cluster Access Issues
- Attempt client-side dry-run with `--dry-run=client --validate=false`
- If client dry-run still fails with API discovery/openapi errors, skip dry-run and rely on lint/schema stages
- Document limitations in validation report

### CRD Documentation Not Found
- Document that documentation lookup failed
- Attempt validation with kubeconform CRD schemas
- Suggest manual CRD inspection:
  ```bash
  kubectl get crd <crd-name>.group -o yaml
  kubectl explain <kind>
  ```

### Validation Stage Failures
- Continue to next stage even if one fails
- Collect all errors before presenting to user
- Prioritize fixing earlier stage errors first

## Communication Guidelines

When presenting validation results:

1. **Be clear and concise** about what was found
2. **Explain why issues matter** (e.g., "This will cause pod creation to fail")
3. **Provide context** from best practices when relevant
4. **Group related issues** (e.g., all missing label issues together)
5. **Use file:line references** for all issues
6. **Show fix complexity** - Include a complexity indicator in the issue header:
   - **[Simple]**: Single-line fixes like indentation, typos, or value changes
   - **[Medium]**: Multi-line changes or adding missing fields/sections
   - **[Complex]**: Logic changes, restructuring, or changes affecting multiple resources

   Example format in issue header:
   ```
   **Issue 1: deployment.yaml:8 - Wrong indentation (Error) [Simple]**
   **Issue 2: deployment.yaml:15-25 - Missing security context (Warning) [Medium]**
   **Issue 3: deployment.yaml - Selector mismatch with Service (Error) [Complex]**
   ```
7. **Always provide a comprehensive report** including:
   - Summary table of all issues by stage
   - Before/after code blocks for each issue
   - Total count of errors and warnings
   - Clear next steps for the user
8. **NEVER offer to apply fixes** - this is strictly a reporting tool
   - Do not ask "Would you like me to fix this?"
   - Do not use AskUserQuestion for fix confirmations
   - Present the report and let the user take action

## Performance Optimization

### Parallel Tool Execution

For improved validation speed, some stages can be executed in parallel:

**Can run in parallel (no dependencies):**
- `yamllint` (Stage 2) and `detect_crd_wrapper.sh` (Stage 3) can run simultaneously
- Both tools operate independently on the input file
- Results from both are needed before proceeding to schema validation

**Example parallel execution:**
```
# Run these in parallel (using & and wait, or parallel tool calls):
yamllint -c "$SKILL_DIR/assets/.yamllint" "$TARGET_FILE"
bash "$SKILL_DIR/scripts/detect_crd_wrapper.sh" "$TARGET_FILE"
```

**Must run sequentially:**
- Stage 0 (Resource Count Check) → Before all other stages
- Stage 1 (Tool Check) → Before using any tools
- Stage 4 (Schema Validation) → After CRD detection (needs CRD info for context)
- Stage 5 (Dry-Run) → After schema validation
- Stage 6 (Report) → After all validation stages complete

**When to parallelize:**
- Files with more than 5 resources benefit most from parallel execution
- For small files (1-2 resources), sequential execution is fine

## Version Awareness

Always consider Kubernetes version compatibility:
- Check for deprecated APIs (e.g., `extensions/v1beta1` → `apps/v1`)
- For CRDs, ensure the apiVersion matches what's in the cluster
- Use `kubectl api-versions` to list available API versions in the cluster
- Reference version-specific documentation when available

## Test Coverage Guidance

The `test/` directory contains example files to exercise all validation paths. Use these to verify skill behavior.

### Test Files

| Test File | Purpose | Expected Behavior |
|-----------|---------|-------------------|
| `deployment-test.yaml` | Valid standard K8s resource | All stages pass, no errors |
| `certificate-crd-test.yaml` | Valid CRD resource | CRD detected, Context7 lookup performed, no errors |
| `comprehensive-test.yaml` | Multi-resource with intentional errors | Syntax error detected, partial parsing works, CRD found |

### Validation Paths to Test

1. **Happy Path (All Valid)**
   - File: `deployment-test.yaml`
   - Expected: All stages pass, report shows "0 errors, 0 warnings"
   - Commands:
```bash
cd "$SKILL_DIR"
python3 scripts/count_yaml_documents.py test/deployment-test.yaml
yamllint -c assets/.yamllint test/deployment-test.yaml
bash scripts/detect_crd_wrapper.sh test/deployment-test.yaml
kubeconform \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -strict -ignore-missing-schemas -summary -verbose \
  test/deployment-test.yaml
kubectl apply --dry-run=server -f test/deployment-test.yaml
```

2. **CRD Detection Path**
   - File: `certificate-crd-test.yaml`
   - Expected: CRD detected, `mcp__context7__resolve-library-id` and `mcp__context7__query-docs` used
   - Commands:
```bash
cd "$SKILL_DIR"
python3 scripts/count_yaml_documents.py test/certificate-crd-test.yaml
bash scripts/detect_crd_wrapper.sh test/certificate-crd-test.yaml
kubeconform \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -strict -ignore-missing-schemas -summary -verbose \
  test/certificate-crd-test.yaml
```

3. **Syntax Error Path**
   - File: `comprehensive-test.yaml`
   - Expected: yamllint catches error, kubeconform reports partial validation, dry-run blocked
   - Commands:
```bash
cd "$SKILL_DIR"
python3 scripts/count_yaml_documents.py test/comprehensive-test.yaml
yamllint -c assets/.yamllint test/comprehensive-test.yaml
bash scripts/detect_crd_wrapper.sh test/comprehensive-test.yaml
kubeconform \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -strict -ignore-missing-schemas -summary -verbose \
  test/comprehensive-test.yaml
kubectl apply --dry-run=server -f test/comprehensive-test.yaml
```

4. **Multi-Resource Partial Parsing**
   - File: `comprehensive-test.yaml` (has 3 resources, 1 with syntax error)
   - Expected: 2/3 resources validated, parse error reported for document 1
   - Commands:
```bash
cd "$SKILL_DIR"
python3 scripts/count_yaml_documents.py test/comprehensive-test.yaml
bash scripts/detect_crd_wrapper.sh test/comprehensive-test.yaml
```

5. **No Cluster Access Path**
   - Any valid file with no kubectl cluster configured
   - Expected: Server-side dry-run fails; client-side fallback is attempted and may still fail if API discovery is unavailable
   - Commands:
```bash
cd "$SKILL_DIR"
KUBECONFIG=/tmp/nonexistent-kubeconfig kubectl apply --dry-run=server -f test/deployment-test.yaml
KUBECONFIG=/tmp/nonexistent-kubeconfig kubectl apply --dry-run=client --validate=false -f test/deployment-test.yaml
```

6. **Missing Tools Path**
   - Test by temporarily removing a tool from PATH
   - Expected: setup_tools.sh reports missing, validation continues with available tools
   - Commands:
```bash
cd "$SKILL_DIR"
PATH="/usr/bin:/bin" bash scripts/setup_tools.sh
```

### Creating New Test Files

When adding test files:
1. Name files descriptively: `<scenario>-test.yaml`
2. Document expected behavior in comments at top of file
3. Include intentional errors for error-path tests
4. Test both standard K8s resources and CRDs

### Expected Report Structure

For any validation, the report should include:
- [ ] Summary table with issue counts by severity
- [ ] Stage-by-stage status table (passed/failed/skipped)
- [ ] Document parsing table (for multi-resource files)
- [ ] Before/after code blocks for each issue
- [ ] Fix complexity indicators ([Simple], [Medium], [Complex])
- [ ] File-absolute line numbers
- [ ] "Next Steps" section

## Done Criteria

Validation is complete only when all conditions are true:
- Stage gates were evaluated in order and every skipped stage includes a reason.
- Resource count came from `count_yaml_documents.py` (or documented AWK fallback).
- CRD lookups used `mcp__context7__resolve-library-id` + `mcp__context7__query-docs`, with `web.search_query` fallback only when needed.
- Report-only boundary was preserved (no edits, no fix-application prompts).
- Output includes exact commands run, findings by severity, and manual next steps.

## Resources

### scripts/

**detect_crd_wrapper.sh**
- Wrapper script that handles Python dependency management
- Automatically creates temporary venv if PyYAML is not available
- Calls detect_crd.py to parse YAML files
- Usage: `bash "$SKILL_DIR/scripts/detect_crd_wrapper.sh" "$TARGET_FILE"`

**detect_crd.py**
- Parses YAML files to identify Custom Resource Definitions
- Extracts kind, apiVersion, group, and version information
- Outputs JSON for programmatic processing
- Requires PyYAML (handled automatically by wrapper script)
- Can be called directly: `python3 "$SKILL_DIR/scripts/detect_crd.py" "$TARGET_FILE"`

**count_yaml_documents.py**
- Deterministically counts non-empty YAML documents in a multi-doc file
- Returns JSON with document count and separators
- Use before Stage 1 to decide whether to load deep workflow reference
- Usage: `python3 "$SKILL_DIR/scripts/count_yaml_documents.py" "$TARGET_FILE"`

**setup_tools.sh**
- Checks for required validation tools
- Provides installation instructions for missing tools
- Verifies versions of installed tools
- Usage: `bash "$SKILL_DIR/scripts/setup_tools.sh"`

### references/

**k8s_best_practices.md**
- Comprehensive guide to Kubernetes YAML best practices
- Covers metadata, labels, resource limits, security context
- Common validation issues and how to fix them
- Load when providing context for validation errors

**validation_workflow.md**
- Detailed validation workflow with all stages
- Command options and configurations
- Error handling strategies
- Complete workflow diagram
- Load for complex validation scenarios

### assets/

**.yamllint**
- Pre-configured yamllint rules for Kubernetes YAML
- Follows Kubernetes conventions (2-space indentation, line length, etc.)
- Can be customized per project
- Usage: `yamllint -c "$SKILL_DIR/assets/.yamllint" "$TARGET_FILE"`
