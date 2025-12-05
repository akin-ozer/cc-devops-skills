---
name: fluentbit-validator
description: Comprehensive toolkit for validating, linting, and testing Fluent Bit configurations. Use this skill when working with Fluent Bit config files, validating syntax, checking for best practices, identifying security issues, or performing dry-run testing.
---

# Fluent Bit Config Validator

## Overview

This skill provides a comprehensive validation workflow for Fluent Bit configurations, combining syntax validation, semantic checks, security auditing, best practice enforcement, and dry-run testing. Validate Fluent Bit configs with confidence before deploying to production.

Fluent Bit uses an INI-like configuration format with sections ([SERVICE], [INPUT], [FILTER], [OUTPUT], [PARSER]) and key-value pairs. This validator ensures configurations are syntactically correct, semantically valid, secure, and optimized for production use.

## When to Use This Skill

Invoke this skill when:
- Validating Fluent Bit configurations before deployment
- Debugging configuration syntax errors
- Testing configurations with fluent-bit --dry-run
- Working with custom plugins that need documentation
- Ensuring configs follow Fluent Bit best practices
- Auditing configurations for security issues
- Optimizing performance settings (buffers, flush intervals)
- The user asks to "validate", "lint", "check", or "test" Fluent Bit configs
- Troubleshooting configuration-related errors

## Validation Workflow

Follow this sequential validation workflow. Each stage catches different types of issues.

> **Recommended:** For comprehensive validation, use `--check all` which runs all validation stages in sequence:
> ```bash
> python3 scripts/validate_config.py --file <config-file> --check all
> ```
> Individual check modes are available for targeted validation when debugging specific issues.

### Stage 1: Configuration File Structure

Verify the basic file structure and format:

```bash
python3 scripts/validate_config.py --file <config-file> --check structure
```

**Expected format:**
- INI-style sections with `[SECTION]` headers
- Key-value pairs with proper spacing
- Comments starting with `#`
- Sections: SERVICE, INPUT, FILTER, OUTPUT, PARSER (or MULTILINE_PARSER)
- Proper indentation (spaces, not tabs recommended)

**Common issues caught:**
- Missing section headers
- Malformed key-value pairs
- Invalid section names
- Syntax errors (unclosed brackets, etc.)
- Mixed tabs and spaces
- UTF-8 encoding issues

### Stage 2: Section Validation

Validate all configuration sections (SERVICE, INPUT, FILTER, OUTPUT, PARSER):

```bash
python3 scripts/validate_config.py --file <config-file> --check sections
```

This single command validates all section types. The checks performed for each section type are detailed below.

#### SERVICE Section Checks

**Checks:**
- Required parameters: Flush
- Valid parameter names (no typos)
- Parameter value types (Flush must be numeric)
- Log_Level values: off, error, warn, info, debug, trace
- HTTP_Server values: On/Off
- Parsers_File references (file existence)

**Common issues:**
- Missing Flush parameter
- Invalid Log_Level value
- Parsers_File path doesn't exist
- Negative or zero Flush interval

**Best practices:**
- Flush: 1-5 seconds (balance latency vs. efficiency)
- Log_Level: info for production, debug for troubleshooting
- HTTP_Server: On (for health checks and metrics)
- storage.metrics: on (for monitoring)

#### INPUT Section Checks

**Checks:**
- Required parameters: Name
- Valid plugin names (tail, systemd, tcp, forward, http, etc.)
- Tag format (no spaces, valid characters)
- File paths exist (for tail plugin)
- Memory limits are set (Mem_Buf_Limit)
- DB file paths are valid
- Port numbers are in valid range (1-65535)

**Common issues:**
- Missing Name parameter
- Invalid plugin name (typo)
- Missing Tag parameter
- Path doesn't exist
- Missing Mem_Buf_Limit (OOM risk)
- Missing DB file (no position tracking)
- Port conflicts

**Best practices:**
- Always set Mem_Buf_Limit (50-100MB typical)
- Use DB for tail inputs (crash recovery)
- Set Skip_Long_Lines On (prevents hang)
- Use appropriate Tag patterns for routing
- Set Refresh_Interval for tail (10 seconds typical)

#### FILTER Section Checks

**Checks:**
- Required parameters: Name, Match (or Match_Regex)
- Valid filter plugin names
- Match pattern syntax
- Tag pattern wildcards are valid
- Filter-specific parameters

**Common issues:**
- Missing Match parameter
- Invalid filter plugin name
- Match pattern doesn't match any INPUT tags
- Missing required plugin-specific parameters

**Best practices:**
- Use specific Match patterns (avoid "*" unless intended)
- Order filters logically (parsers before modifiers)
- Use kubernetes filter in K8s environments
- Parse JSON logs early in pipeline

#### OUTPUT Section Checks

**Checks:**
- Required parameters: Name, Match
- Valid output plugin names (including elasticsearch, kafka, loki, s3, cloudwatch, http, forward, file, opentelemetry)
- Host/Port validity
- Retry_Limit is set
- Storage limits are configured
- TLS configuration (if enabled)
- OpenTelemetry-specific: URI endpoints (metrics_uri, logs_uri, traces_uri), authentication headers, resource attributes

**Common issues:**
- Missing Match parameter
- Invalid output plugin name
- Match pattern doesn't match any INPUT tags
- Missing Retry_Limit (infinite retries risk)
- Missing storage.total_limit_size (disk exhaustion risk)
- Hardcoded credentials (security issue)

**Best practices:**
- Set Retry_Limit 3-5
- Configure storage.total_limit_size
- Enable TLS in production
- Use environment variables for credentials
- Enable compression when available

#### PARSER Section Checks

**Checks:**
- Required parameters: Name, Format
- Valid parser formats: json, regex, logfmt, ltsv
- Regex syntax validity
- Time_Format compatibility with Time_Key
- MULTILINE_PARSER rule syntax

**Common issues:**
- Invalid regex patterns
- Time_Format doesn't match log timestamps
- Missing Time_Key when using Time_Format
- MULTILINE_PARSER rules don't match

**Best practices:**
- Test regex patterns with sample logs
- Use built-in parsers when possible
- Set proper Time_Format for timestamp parsing
- Use MULTILINE_PARSER for stack traces

### Stage 3: Tag Consistency Check

Validate that tags flow correctly through the pipeline:

```bash
python3 scripts/validate_config.py --file <config-file> --check tags
```

**Checks:**
- INPUT tags match FILTER Match patterns
- FILTER tags match OUTPUT Match patterns
- No orphaned filters (Match pattern doesn't match any INPUT)
- No orphaned outputs (Match pattern doesn't match any INPUT/FILTER)
- Tag wildcards are used correctly

**Common issues:**
- FILTER Match pattern doesn't match any INPUT Tag
- OUTPUT Match pattern doesn't match any logs
- Typo in Match pattern
- Incorrect wildcard usage

**Example validation:**
```ini
[INPUT]
    Tag    kube.*     # Produces: kube.var.log.containers.pod.log

[FILTER]
    Match  kube.*     # Matches: ✅

[OUTPUT]
    Match  app.*      # Matches: ❌ No logs will reach this output
```

### Stage 4: Security Audit

Scan configuration for security issues:

```bash
python3 scripts/validate_config.py --file <config-file> --check security
```

**Checks performed:**

1. **Hardcoded credentials:**
   - HTTP_User, HTTP_Passwd in OUTPUT
   - AWS_Access_Key, AWS_Secret_Key
   - Passwords in plain text
   - API keys and tokens

2. **TLS configuration:**
   - TLS disabled for production outputs
   - tls.verify Off (man-in-the-middle risk)
   - Missing certificate files

3. **File permissions:**
   - DB files readable/writable
   - Parser files exist and readable
   - Log files have appropriate permissions

4. **Network exposure:**
   - INPUT plugins listening on 0.0.0.0 without auth
   - Open ports without firewall mentions
   - HTTP_Server exposed without auth

**Security best practices:**
- Use environment variables: `HTTP_User ${ES_USER}`
- Enable TLS: `tls On`
- Verify certificates: `tls.verify On`
- Don't listen on 0.0.0.0 for sensitive inputs
- Use authentication for HTTP endpoints

**Auto-fix suggestions:**
```ini
# Before (insecure)
[OUTPUT]
    HTTP_User     admin
    HTTP_Passwd   password123

# After (secure)
[OUTPUT]
    HTTP_User     ${ES_USER}
    HTTP_Passwd   ${ES_PASSWORD}
```

### Stage 5: Performance Analysis

Analyze configuration for performance issues:

```bash
python3 scripts/validate_config.py --file <config-file> --check performance
```

**Checks:**

1. **Buffer limits:**
   - Mem_Buf_Limit is set on all tail inputs
   - storage.total_limit_size is set on outputs
   - Limits are reasonable (not too small or too large)

2. **Flush intervals:**
   - Flush interval is appropriate (1-5 sec typical)
   - Not too low (high CPU) or too high (high memory)

3. **Resource usage:**
   - Skip_Long_Lines enabled (prevents hang)
   - Refresh_Interval set (file discovery)
   - Compression enabled on network outputs

4. **Kubernetes-specific:**
   - Buffer_Size 0 for kubernetes filter (recommended)
   - Mem_Buf_Limit not too low for container logs

**Performance recommendations:**

```ini
# Good configuration
[SERVICE]
    Flush        1              # 1 second: good balance

[INPUT]
    Mem_Buf_Limit     50MB      # Prevents OOM
    Skip_Long_Lines   On        # Prevents hang
    Refresh_Interval  10        # File discovery every 10s

[OUTPUT]
    storage.total_limit_size 5G # Disk buffer limit
    Retry_Limit       3         # Don't retry forever
    Compress          gzip      # Reduce bandwidth
```

### Stage 6: Best Practice Validation

Check against Fluent Bit best practices:

```bash
python3 scripts/validate_config.py --file <config-file> --check best-practices
```

**Checks:**

1. **Required configurations:**
   - SERVICE section exists
   - At least one INPUT
   - At least one OUTPUT
   - HTTP_Server enabled (for health checks)

2. **Kubernetes configurations:**
   - kubernetes filter used for K8s logs
   - Proper Kube_URL, Kube_CA_File, Kube_Token_File
   - Exclude_Path to prevent log loops
   - DB file for position tracking

3. **Reliability:**
   - Retry_Limit set on outputs
   - DB file for tail inputs
   - storage.type filesystem for critical logs

4. **Observability:**
   - HTTP_Server enabled
   - storage.metrics enabled
   - Proper Log_Level (info or debug)

**Best practice checklist:**
- ✅ SERVICE section with Flush parameter
- ✅ HTTP_Server enabled for health checks
- ✅ Mem_Buf_Limit on all tail inputs
- ✅ DB file for tail inputs (position tracking)
- ✅ Retry_Limit on all outputs
- ✅ storage.total_limit_size on outputs
- ✅ TLS enabled for production
- ✅ Environment variables for credentials
- ✅ kubernetes filter for K8s environments
- ✅ Exclude_Path to prevent log loops

### Stage 7: Dry-Run Testing

Test configuration with Fluent Bit dry-run (if binary available):

```bash
fluent-bit -c <config-file> --dry-run
```

**This catches:**
- Configuration parsing errors
- Plugin loading errors
- Parser syntax errors
- File permission issues
- Missing dependencies

**Common errors:**

1. **Parser file not found:**
```
[error] [config] parser file 'parsers.conf' not found
```
Fix: Create parser file or update Parsers_File path

2. **Plugin not found:**
```
[error] [plugins] invalid plugin 'unknownplugin'
```
Fix: Check plugin name spelling or install plugin

3. **Invalid parameter:**
```
[error] [input:tail] invalid property 'InvalidParam'
```
Fix: Remove invalid parameter or check documentation

4. **Permission denied:**
```
[error] cannot open /var/log/containers/*.log
```
Fix: Check file permissions or run with appropriate user

**If fluent-bit binary is not available:**
- Skip this stage
- Document that dry-run testing was skipped
- Recommend testing in development environment

### Stage 8: Documentation Lookup (if needed)

If configuration uses unfamiliar plugins or parameters:

**Try context7 MCP first:**
```
Use mcp__context7__resolve-library-id with "fluent-bit"
Then use mcp__context7__get-library-docs with:
- context7CompatibleLibraryID: /fluent/fluent-bit-docs
- topic: "<plugin-type> <plugin-name> configuration"
- page: 1
```

**Fallback to WebSearch:**
```
Search query: "fluent-bit <plugin-type> <plugin-name> configuration parameters site:docs.fluentbit.io"

Examples:
- "fluent-bit output elasticsearch configuration parameters site:docs.fluentbit.io"
- "fluent-bit filter kubernetes configuration parameters site:docs.fluentbit.io"
```

**Extract information:**
- Required parameters
- Optional parameters and defaults
- Valid value ranges
- Example configurations

### Stage 9: Report and Fix Issues

After validation, present comprehensive findings:

**1. Summarize all issues:**
```
Validation Report for fluent-bit.conf
=====================================

Errors (3):
  - [Line 15] OUTPUT elasticsearch missing required parameter 'Host'
  - [Line 25] FILTER Match pattern 'app.*' doesn't match any INPUT tags
  - [Line 8] INPUT tail missing Mem_Buf_Limit (OOM risk)

Warnings (2):
  - [Line 30] OUTPUT elasticsearch has hardcoded password (security risk)
  - [Line 12] INPUT tail missing DB file (no crash recovery)

Info (1):
  - [Line 3] SERVICE Flush interval is 10s (consider reducing for lower latency)

Best Practices (2):
  - Consider enabling HTTP_Server for health checks
  - Consider enabling compression on OUTPUT elasticsearch
```

**2. Categorize by severity:**
- **Errors (must fix):** Configuration won't work, Fluent Bit won't start
- **Warnings (should fix):** Configuration works but has issues
- **Info (consider):** Optimization opportunities
- **Best Practices:** Recommended improvements

**3. Propose specific fixes:**
```ini
# Fix 1: Add missing Host parameter
[OUTPUT]
    Name  es
    Match *
    Host  elasticsearch.logging.svc  # Added
    Port  9200

# Fix 2: Add Mem_Buf_Limit to prevent OOM
[INPUT]
    Name              tail
    Tag               kube.*
    Path              /var/log/containers/*.log
    Mem_Buf_Limit     50MB  # Added

# Fix 3: Use environment variable for password
[OUTPUT]
    Name        es
    HTTP_User   admin
    HTTP_Passwd ${ES_PASSWORD}  # Changed from hardcoded
```

**4. Get user approval** via AskUserQuestion

**5. Apply approved fixes** using Edit tool

**6. Re-run validation** to confirm

**7. Provide completion summary:**
```
✅ Validation Complete - 5 issues fixed

Fixed Issues:
  - fluent-bit.conf:15 - Added missing Host parameter to OUTPUT elasticsearch
  - fluent-bit.conf:8 - Added Mem_Buf_Limit 50MB to INPUT tail
  - fluent-bit.conf:30 - Changed hardcoded password to environment variable
  - fluent-bit.conf:12 - Added DB file for crash recovery
  - fluent-bit.conf:25 - Fixed FILTER Match pattern to match INPUT tags

Validation Status: All checks passed ✅
  - Structure: Valid
  - Syntax: Valid
  - Tags: Consistent
  - Security: No issues
  - Performance: Optimized
  - Best Practices: Compliant
  - Dry-run: Passed (if applicable)
```

**8. Report-only summary (when user declines fixes):**

If user chooses not to apply fixes, provide a report-only summary:
```
📋 Validation Report Complete - No fixes applied

Summary:
  - Errors: 2 (must fix before deployment)
  - Warnings: 16 (should fix)
  - Info: 15 (optimization suggestions)

Critical Issues Requiring Attention:
  - [Line 5] Invalid Log_Level 'invalid_level'
  - [Line 52] [OUTPUT opentelemetry] missing required parameter 'Host'

Recommendations:
  - Review the errors above before deploying this configuration
  - Consider addressing warnings to improve reliability and security
  - Run validation again after manual fixes: python3 scripts/validate_config.py --file <config> --check all
```

## Common Issues and Solutions

### Configuration Errors

**Issue: Parser file not found**
```
[error] [config] parser file 'parsers.conf' not found
```
Solution:
- Verify Parsers_File path in SERVICE section
- Check if file exists at specified location
- Use relative path from config file location

**Issue: Missing required parameter**
```
[error] [output:es] property 'Host' not set
```
Solution:
- Add required parameter to OUTPUT section
- Check documentation for required fields

**Issue: Invalid plugin name**
```
[error] [plugins] invalid plugin 'unknownplugin'
```
Solution:
- Check plugin name spelling
- Verify plugin is available (may need installation)
- Consult documentation for correct plugin names

### Tag Routing Issues

**Issue: No logs reaching output**
```
# Logs are generated but don't appear in output
```
Debug:
1. Check INPUT Tag matches FILTER Match
2. Check FILTER Match/tag_prefix matches OUTPUT Match
3. Enable debug logging: `Log_Level debug`
4. Check for grep filters excluding all logs

Solution:
```ini
[INPUT]
    Tag    kube.*

[FILTER]
    Match  kube.*    # Must match INPUT Tag

[OUTPUT]
    Match  kube.*    # Must match INPUT or FILTER tag
```

### Memory Issues

**Issue: Fluent Bit OOM killed**
```
# Container or process killed due to memory
```
Solution:
- Add Mem_Buf_Limit to all tail inputs
- Reduce Mem_Buf_Limit values
- Set storage.total_limit_size on outputs
- Increase Flush interval (batch more)
- Add log filtering to reduce volume

### Security Issues

**Issue: Hardcoded credentials in config**
```
[OUTPUT]
    HTTP_Passwd  secretpassword
```
Solution:
- Use environment variables:
```ini
[OUTPUT]
    HTTP_Passwd  ${ES_PASSWORD}
```
- Mount secrets in Kubernetes
- Use IAM roles for cloud services (AWS, GCP, Azure)

**Issue: TLS disabled or not verified**
```
[OUTPUT]
    tls On
    tls.verify Off
```
Solution:
- Enable verification for production:
```ini
[OUTPUT]
    tls         On
    tls.verify  On
    tls.ca_file /path/to/ca.crt
```

## Integration with fluentbit-generator

This validator is automatically invoked by the fluentbit-generator skill after generating configurations. It can also be used standalone to validate existing configurations.

**Generator workflow:**
1. Generate configuration using fluentbit-generator
2. Automatically validate using fluentbit-validator
3. Fix any issues found
4. Re-validate until all checks pass
5. Deploy with confidence

## Resources

### scripts/

**validate_config.py**
- Main validation script with all checks integrated in a single file
- Usage: `python3 scripts/validate_config.py --file <config> --check <type>`
- Available check types: `all`, `structure`, `syntax`, `sections`, `tags`, `security`, `performance`, `best-practices`, `dry-run`
- Comprehensive 1000+ line validator covering all validation stages
- Includes syntax validation, section validation, tag consistency, security audit, performance analysis, and best practices
- Returns detailed error messages with line numbers
- Supports JSON output format: `--json`

**validate.sh**
- Convenience wrapper script for easier invocation
- Usage: `bash scripts/validate.sh <config-file>`
- Automatically calls validate_config.py with proper Python interpreter
- Simplifies command-line usage

### tests/

**Test Configuration Files:**
- `valid-basic.conf` - Valid basic Kubernetes logging setup
- `valid-multioutput.conf` - Valid configuration with multiple outputs
- `valid-opentelemetry.conf` - Valid OpenTelemetry output configuration (Fluent Bit 2.x+)
- `invalid-missing-required.conf` - Missing required parameters
- `invalid-security-issues.conf` - Security vulnerabilities (hardcoded credentials, disabled TLS)
- `invalid-opentelemetry.conf` - OpenTelemetry configuration errors
- `invalid-tag-mismatch.conf` - Tag routing issues

**Running Tests:**
```bash
# Test on valid config
python3 scripts/validate_config.py --file tests/valid-basic.conf

# Test on invalid config (should report errors)
python3 scripts/validate_config.py --file tests/invalid-security-issues.conf

# Test all configs
for config in tests/*.conf; do
    echo "Testing $config"
    python3 scripts/validate_config.py --file "$config"
done
```

### Documentation Sources

Based on comprehensive research from:

- [Fluent Bit Official Documentation](https://docs.fluentbit.io/manual)
- [Fluent Bit Operations and Best Practices](https://fluentbit.net/fluent-bit-operations-and-best-practices/)
- [Configuration File Format](https://docs.fluentbit.io/manual/administration/configuring-fluent-bit/classic-mode/configuration-file)
- Context7 Fluent Bit documentation (/fluent/fluent-bit-docs)