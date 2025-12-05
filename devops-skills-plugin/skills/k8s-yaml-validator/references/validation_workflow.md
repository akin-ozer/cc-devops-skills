# Kubernetes YAML Validation Workflow

This document outlines the comprehensive validation workflow for Kubernetes YAML resources.

## Validation Stages

### Stage 1: YAML Syntax Validation (yamllint)

**Purpose:** Catch YAML syntax errors and style issues before Kubernetes-specific validation.

**Command:**
```bash
yamllint <file.yaml>
```

**Common Issues Detected:**
- Indentation errors (tabs vs spaces)
- Line length violations
- Trailing spaces
- Missing document start markers
- Duplicate keys
- Syntax errors

**Configuration:**
Create a `.yamllint` config file for custom rules:
```yaml
extends: default
rules:
  line-length:
    max: 120
  indentation:
    spaces: 2
  comments:
    min-spaces-from-content: 1
```

### Stage 2: Kubernetes Schema Validation (kubeconform)

**Purpose:** Validate against Kubernetes schemas and detect structural issues.

**Basic Command:**
```bash
kubeconform -summary <file.yaml>
```

**With CRD Support (recommended):**
```bash
kubeconform \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -strict \
  -ignore-missing-schemas \
  -summary \
  -verbose \
  <file.yaml>
```

**Options:**
- `-strict`: Reject resources with unknown fields (catches typos - recommended for production)
- `-ignore-missing-schemas`: Skip validation for CRDs without available schemas
- `-kubernetes-version <version>`: Validate against specific K8s version (e.g., 1.30.0)
- `-output json`: Output results as JSON

**Common Issues Detected:**
- Invalid apiVersion
- Missing required fields
- Invalid field types
- Unknown fields (in strict mode)
- Invalid enum values

### Stage 3: Cluster Dry-Run (kubectl)

**Purpose:** Validate against the actual cluster configuration, admission controllers, and policies.

**Client-Side Dry Run:**
```bash
kubectl apply --dry-run=client -f <file.yaml>
```
- Validates against basic Kubernetes API rules
- Does not contact the cluster
- Fast but less thorough

**Server-Side Dry Run:**
```bash
kubectl apply --dry-run=server -f <file.yaml>
```
- Full validation including admission controllers
- Validates against cluster-specific constraints
- Requires cluster access
- Catches issues like:
  - Resource quota violations
  - Policy violations (PSP, OPA, Kyverno)
  - Admission webhook rejections
  - Namespace existence
  - ConfigMap/Secret references

**Diff Mode (for updates):**
```bash
kubectl diff -f <file.yaml>
```
Shows what would change if applied to the cluster.

## CRD Detection and Documentation Lookup

### Step 1: Detect CRDs

Use the `detect_crd.py` script:
```bash
python3 scripts/detect_crd.py <file.yaml>
```

Output example:
```json
[
  {
    "kind": "Certificate",
    "apiVersion": "cert-manager.io/v1",
    "group": "cert-manager.io",
    "version": "v1",
    "isCRD": true,
    "name": "example-cert"
  }
]
```

### Step 2: Lookup CRD Documentation

For each detected CRD:

1. **Use context7 MCP (preferred):**
   - Resolve library ID: `mcp__context7__resolve-library-id` with the CRD group/project name
   - Fetch documentation: `mcp__context7__get-library-docs` with the library ID
   - Focus on the specific version if available

2. **Fallback to Web Search:**
   - Search query: `"<kind>" "<group>" kubernetes CRD "<version>" documentation`
   - Example: `"Certificate" "cert-manager.io" kubernetes CRD "v1" documentation`
   - Look for official documentation sites
   - Check for API references and examples

### Step 3: Validate Against CRD Schema

Once documentation is found:
- Check required fields in spec
- Verify field types and formats
- Validate enum values
- Check for version-specific changes

## Complete Validation Workflow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Check Tools                                              │
│    Run: scripts/setup_tools.sh                              │
│    Ensure yamllint, kubeconform, kubectl are installed      │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. YAML Syntax Check                                        │
│    Run: yamllint <file.yaml>                                │
│    Fix: Indentation, trailing spaces, syntax errors         │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Detect CRDs                                              │
│    Run: python3 scripts/detect_crd.py <file.yaml>           │
│    Parse: Extract kind, apiVersion, group                   │
└─────────────────────────────────────────────────────────────┘
                           ↓
                    ┌──────┴──────┐
                    │             │
                [CRD?]          [Standard Resource]
                    │             │
                    ↓             ↓
     ┌──────────────────────┐    │
     │ 4a. Lookup CRD Docs   │    │
     │    - context7 MCP     │    │
     │    - Web search       │    │
     │    - Version-aware    │    │
     └──────────────────────┘    │
                    │             │
                    └──────┬──────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Schema Validation                                        │
│    Run: kubeconform -summary <file.yaml>                    │
│    Fix: Required fields, types, unknown fields              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Dry-Run (if cluster available)                           │
│    Run: kubectl apply --dry-run=server -f <file.yaml>       │
│    Fix: Admission issues, quotas, policies                  │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. Generate Validation Report                               │
│    - Summarize all issues in table format                   │
│    - Show before/after code blocks for each issue           │
│    - Do NOT modify files - report only                      │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. Provide Next Steps                                       │
│    - List errors that must be fixed                         │
│    - List warnings for best practices                       │
│    - User decides which fixes to apply                      │
└─────────────────────────────────────────────────────────────┘
```

## Error Handling

### Tool Not Found
- Run `scripts/setup_tools.sh` to check tool availability
- Provide installation instructions
- Skip optional validation stages if tools missing

### Cluster Not Available
- Skip server-side dry-run
- Use client-side dry-run and kubeconform instead
- Warn user that some validations are skipped

### CRD Documentation Not Found
- Document that CRD docs couldn't be found
- Attempt validation with kubeconform CRD schemas
- Suggest checking cluster for CRD definition:
  ```bash
  kubectl get crd <crd-name> -o yaml
  ```

### Multiple Resources in One File
- Validate each resource separately
- Track which resource has issues
- Provide line numbers for error locations

## Best Practices for Validation

1. **Always validate in order:** syntax → schema → dry-run
2. **Collect all issues:** Don't stop at first error - gather everything before reporting
3. **For CRDs:** Always look up documentation first
4. **Version awareness:** Check K8s version compatibility
5. **Test with cluster:** Server-side dry-run is the most reliable
6. **Show before/after:** Display code blocks showing suggested fixes
7. **Provide context:** Explain what each issue means and why the fix is needed
8. **Report only:** Do NOT modify files - let user decide which fixes to apply
9. **Load best practices reference:** When schema errors occur, load k8s_best_practices.md for context

## Creating Validation Reports

Generate a comprehensive validation report with all findings. Do NOT modify files.

### Report Components

1. **Header with issue count**
   ```
   ## Validation Report - 7 issues found (4 errors, 3 warnings)
   ```

2. **Issues Summary Table**
   ```
   | Severity | Stage | Location | Issue | Suggested Fix |
   |----------|-------|----------|-------|---------------|
   | Error | Syntax | file.yaml:8 | Wrong indentation | Use 2 spaces |
   | Error | Schema | file.yaml:21 | Wrong type | Change to integer |
   | Warning | Best Practice | file.yaml:30 | Missing labels | Add app label |
   ```

3. **Detailed Findings** (for each issue)
   - File:line reference
   - Current code block
   - Suggested fix code block
   - Explanation of why it matters

4. **Validation status by stage**
   - Show which stages passed/failed
   - Note if any stages were skipped (e.g., no cluster access)

5. **Next Steps**
   - List errors that must be fixed before deployment
   - List warnings for best practices consideration
   - Suggest re-running validation after fixes

### Example Report Format

```
## Validation Report - 7 issues found

File: deployment.yaml
Resources Analyzed: 3 (Deployment, Service, Certificate)

| Stage | Status | Issues |
|-------|--------|--------|
| YAML Syntax | ❌ Failed | 2 errors |
| CRD Detection | ✅ Passed | 1 CRD found |
| Schema Validation | ❌ Failed | 2 errors |
| Dry-Run | ❌ Failed | 1 error |

### Issue 1: deployment.yaml:8 - Wrong indentation (Error)

Current:
```yaml
    labels:
```

Suggested Fix:
```yaml
  labels:
```

**Why:** Kubernetes YAML requires 2-space indentation.

### Issue 2: deployment.yaml:21 - Wrong field type (Error)

Current:
```yaml
        - containerPort: "80"
```

Suggested Fix:
```yaml
        - containerPort: 80
```

**Why:** containerPort must be an integer, not a string.

[... more issues ...]

## Next Steps

1. Fix the 4 errors listed above (deployment will fail without these)
2. Consider addressing the 3 warnings for best practices
3. Re-run validation to confirm all issues resolved
```

### Report Best Practices

- **Be specific:** List every issue with exact location
- **Show both current and suggested:** Always show before/after code blocks
- **Explain impact:** Help user understand why each issue matters
- **Group by file:** When multiple files are involved
- **Prioritize by severity:** Errors first, then warnings, then info
- **Provide file references:** Always include file:line for traceability
- **Clear next steps:** Tell user exactly what to do
