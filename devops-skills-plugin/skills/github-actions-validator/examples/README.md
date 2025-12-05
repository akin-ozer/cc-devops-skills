# GitHub Actions Validator - Example Workflows

This directory contains example workflow files for testing the GitHub Actions Validator skill.

## Files

### valid-ci.yml

A complete, valid CI pipeline that passes all validation checks.

**Purpose:** Test successful validation flow

**Usage:**
```bash
bash scripts/validate_workflow.sh examples/valid-ci.yml
```

**Expected Result:** All validations pass

---

### with-errors.yml

A workflow containing common intentional errors for testing error detection.

**Purpose:** Test error detection and reference file consultation

**Errors included:**
1. Typo in runner label (`ubuntu-lastest` instead of `ubuntu-latest`)
2. Invalid CRON expression (day 8 doesn't exist)
3. Invalid glob pattern (`**.js` instead of `**/*.js`)
4. Undefined job dependency (`biuld` instead of `build`)
5. Script injection vulnerability (untrusted input in script)

**Usage:**
```bash
bash scripts/validate_workflow.sh examples/with-errors.yml
```

**Expected Result:** Multiple errors reported by actionlint

---

### outdated-versions.yml

A workflow using older action versions to test version validation.

**Purpose:** Test action version checking

**Version issues included:**
1. `actions/checkout@v4` - OUTDATED (current: v6)
2. `actions/setup-node@v4` - OUTDATED (current: v6)
3. `actions/upload-artifact@v3` - DEPRECATED (minimum: v4)
4. `docker/build-push-action@v5` - OUTDATED (current: v6)

**Usage:**
```bash
bash scripts/validate_workflow.sh --check-versions examples/outdated-versions.yml
```

**Expected Result:** Version warnings for outdated actions

---

## Testing Workflow

1. **Test successful validation:**
   ```bash
   bash scripts/validate_workflow.sh examples/valid-ci.yml
   ```

2. **Test error detection:**
   ```bash
   bash scripts/validate_workflow.sh examples/with-errors.yml
   ```

3. **Test version checking:**
   ```bash
   bash scripts/validate_workflow.sh --check-versions examples/outdated-versions.yml
   ```

4. **Test all examples:**
   ```bash
   for file in examples/*.yml; do
     echo "=== Testing: $file ==="
     bash scripts/validate_workflow.sh --lint-only "$file"
     echo ""
   done
   ```