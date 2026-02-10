---
name: jenkinsfile-validator
description: Comprehensive toolkit for validating, linting, testing, and automating Jenkinsfile pipelines (both Declarative and Scripted). Use this skill when working with Jenkins pipeline files, validating pipeline syntax, checking best practices, debugging pipeline issues, or working with custom plugins.
---

# Jenkinsfile Validator Skill

Comprehensive toolkit for validating, linting, and testing Jenkinsfile pipelines (both Declarative and Scripted). This skill applies when working with Jenkins pipeline files, validating pipeline syntax, checking best practices, debugging pipeline issues, or working with custom plugins that require documentation lookup.

## When to Use This Skill

- Validating Jenkinsfile syntax before committing to repository
- Checking Jenkins pipeline best practices compliance
- Debugging pipeline syntax errors or configuration issues
- Validating both Declarative and Scripted pipeline syntaxes
- **Validating Jenkins Shared Library files (vars/*.groovy, src/**/*.groovy)**
- Working with plugin-specific steps that need documentation
- Ensuring proper credential handling and security practices
- Checking for common anti-patterns and performance issues
- Verifying variable usage and scope

## Validation Capabilities

### Declarative Pipeline Validation
- **Syntax Structure**: Validates required sections (pipeline, agent, stages, steps)
- **Directive Validation**: Checks proper usage of environment, options, parameters, triggers, tools, when, input
- **Best Practices**: Parallel execution, credential management, combined shell commands
- **Section Placement**: Ensures directives are in correct locations

### Scripted Pipeline Validation
- **Groovy Syntax**: Validates Groovy code syntax and structure
- **Node Blocks**: Ensures proper node/agent block usage
- **Error Handling**: Checks for try-catch-finally patterns
- **Best Practices**: @NonCPS usage, agent-based operations, proper variable scoping

### Common Validations (Both Types)
- **Security**: Detects hardcoded credentials, passwords, API keys
- **Performance**: Identifies controller-heavy operations (JsonSlurper, HttpRequest on controller)
- **Variables**: Validates variable declarations and usage
- **Plugins**: Detects and validates plugin-specific steps with dynamic documentation lookup

### Shared Library Validation
- **vars/*.groovy**: Validates global variable files (callable steps)
  - call() method presence and signature
  - @NonCPS annotation correctness (no pipeline steps in @NonCPS methods)
  - CPS compatibility (closures with .each{}, .collect{}, etc.)
  - Hardcoded credentials detection
  - Controller-heavy operations (JsonSlurper, new URL(), new File())
  - Thread.sleep() vs sleep() step
  - System.getenv() vs env.VAR_NAME
  - File naming conventions (camelCase)
  - Documentation comment presence
- **src/**/*.groovy**: Validates Groovy source class files
  - Package declaration presence
  - Class naming matches filename
  - Serializable implementation (required for CPS)
  - Wildcard import warnings
  - Static method CPS compatibility

## Pipeline Type Detection

The skill automatically detects the pipeline type:
- **Declarative**: Starts with `pipeline {` block
- **Scripted**: Starts with `node` or contains Groovy code outside pipeline block
- **Ambiguous**: Will ask for clarification if uncertain

## Core Validation Workflow

Follow this workflow when validating Jenkinsfiles to catch issues early and ensure pipeline quality:

### Quick Start - Full Validation (Recommended)

```bash
# Run complete validation (syntax + security + best practices)
bash scripts/validate_jenkinsfile.sh Jenkinsfile
```

This single command:
1. Auto-detects pipeline type (Declarative/Scripted)
2. Runs syntax validation
3. Runs security scan (credential detection)
4. Runs best practices check
5. Provides a unified summary with pass/fail status

### Validation Options

```bash
# Full validation (default)
bash scripts/validate_jenkinsfile.sh Jenkinsfile

# Syntax validation only (fastest)
bash scripts/validate_jenkinsfile.sh --syntax-only Jenkinsfile

# Security audit only
bash scripts/validate_jenkinsfile.sh --security-only Jenkinsfile

# Best practices check only
bash scripts/validate_jenkinsfile.sh --best-practices Jenkinsfile

# Skip security checks
bash scripts/validate_jenkinsfile.sh --no-security Jenkinsfile

# Skip best practices
bash scripts/validate_jenkinsfile.sh --no-best-practices Jenkinsfile

# Strict mode (fail on warnings)
bash scripts/validate_jenkinsfile.sh --strict Jenkinsfile
```

### Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Type Detection (Automatic)                               │
│    ├─ Declarative: starts with 'pipeline {'                 │
│    └─ Scripted: starts with 'node' or Groovy code          │
│         ↓                                                   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Syntax Validation (Required)                             │
│    ├─ Structure validation                                  │
│    ├─ Required sections                                     │
│    └─ Groovy syntax                                         │
│         ↓                                                   │
│    Reports errors → Continues to next phase                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Security Scan (Required)                                 │
│    ├─ Hardcoded credentials                                 │
│    ├─ API keys / tokens                                     │
│    ├─ Cloud provider credentials                            │
│    └─ Private keys / certificates                           │
│         ↓                                                   │
│    Reports issues → Continues to next phase                 │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Best Practices Check (Recommended)                       │
│    ├─ Combined shell commands                               │
│    ├─ Timeout configuration                                 │
│    ├─ Workspace cleanup                                     │
│    ├─ Error handling                                        │
│    └─ Test result publishing                                │
│         ↓                                                   │
│    Reports suggestions → Complete with summary              │
└─────────────────────────────────────────────────────────────┘

**Note:** All validation phases run regardless of errors found in previous phases.
This ensures comprehensive reporting of all issues in a single run.
```

### Script Architecture

The validation system uses a modular script architecture:

```
scripts/
├── validate_jenkinsfile.sh      # Main orchestrator (USE THIS)
│   ├── Auto-detects pipeline type
│   ├── Runs syntax validation
│   ├── Runs security scan
│   ├── Runs best practices check
│   └── Produces unified summary
│
├── validate_declarative.sh      # Declarative syntax validator
│   └── Called automatically for pipeline {} blocks
│
├── validate_scripted.sh         # Scripted syntax validator
│   └── Called automatically for node {} blocks
│
├── common_validation.sh         # Shared functions + security scan
│   ├── detect_type: Determine pipeline type
│   ├── check_credentials: Security credential scan
│   └── Common utilities
│
├── best_practices.sh            # 15-point best practices scorer
│   └── Performance, security, maintainability checks
│
└── validate_shared_library.sh   # Shared library validator
    └── For vars/*.groovy and src/**/*.groovy files
```

**Key Point**: Always use `validate_jenkinsfile.sh` as the main entry point - it orchestrates all other scripts automatically.

### Individual Scripts (Advanced Usage)

If you need to run validators separately (for debugging or specific checks):

```bash
# Detect pipeline type
bash scripts/common_validation.sh detect_type Jenkinsfile

# Run syntax validation only
bash scripts/validate_declarative.sh Jenkinsfile  # For declarative
bash scripts/validate_scripted.sh Jenkinsfile     # For scripted

# Run security checks only
bash scripts/common_validation.sh check_credentials Jenkinsfile

# Run best practices check only
bash scripts/best_practices.sh Jenkinsfile
```

### Shared Library Validation

Validate Jenkins Shared Library files using `validate_shared_library.sh`:

```bash
# Validate a single vars file
bash scripts/validate_shared_library.sh vars/myStep.groovy

# Validate entire shared library directory
bash scripts/validate_shared_library.sh /path/to/shared-library

# Validate just vars directory
bash scripts/validate_shared_library.sh vars/

# Validate just src directory
bash scripts/validate_shared_library.sh src/
```

The shared library validator checks:
- **vars/*.groovy files**: call() method, @NonCPS usage, CPS compatibility, credential handling
- **src/**/*.groovy files**: Package declaration, class naming, Serializable implementation, imports

Example output:
```
=== Validating Global Variable: myStep ===
File: vars/myStep.groovy

=== Validation Results ===

ERRORS (2):
ERROR [Line 15]: @NonCPS method contains pipeline steps (sh, echo, etc.)
ERROR [Line 15]:   → Pipeline steps cannot be used in @NonCPS methods

WARNINGS (3):
WARNING [Line 22]: Using 'new File()' - prefer readFile/writeFile for pipeline compatibility
WARNING [Line 1]: No call() method found - file may not be callable as a step
WARNING [Line 1]: Filename 'BadStep' should be camelCase starting with lowercase

=== Summary ===
✗ Validation failed with 2 error(s) and 3 warning(s)
```

## Plugin Documentation Lookup

**Important**: Plugin documentation lookup is Claude's responsibility (not automated in scripts). After running validation, Claude should identify unknown plugins and look them up.

### When to Look Up Plugin Documentation

Look up documentation when you encounter:
- Steps not in `references/common_plugins.md` (e.g., `customDeploy`, `sendToDatadog`, `grafanaNotify`)
- Plugin-specific configuration (e.g., `nexusArtifactUploader`, `sonarQubeScanner`)
- User questions about plugin parameters or best practices

### Plugin Lookup Workflow (Claude's Responsibility)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Identify Unknown Plugin Step                             │
│    - Review Jenkinsfile for unrecognized steps              │
│    - Example: customDeploy, nexusPublish, datadogEvent      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Check Local Reference First                              │
│    - Read: references/common_plugins.md                     │
│    - Contains: git, docker, kubernetes, credentials, etc.   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Use Context7 MCP (if not in local reference)            │
│    - mcp__context7__resolve-library-id                      │
│      query: "jenkinsci <plugin-name>-plugin"               │
│    - mcp__context7__get-library-docs                        │
│      for usage examples and parameters                      │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Web Search Fallback (if Context7 has no results)        │
│    - WebSearch: "Jenkins <plugin-name> plugin documentation"│
│    - Official source: https://plugins.jenkins.io/           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Provide Usage Guidance                                   │
│    - Required vs optional parameters                        │
│    - Best practices for the plugin                          │
│    - Security considerations                                │
└─────────────────────────────────────────────────────────────┘
```

### Example: Unknown Plugin Detection
```groovy
// User's Jenkinsfile contains:
stage('Deploy') {
    steps {
        nexusArtifactUploader artifacts: [[...]], nexusUrl: 'http://nexus'
        datadogEvent title: 'Deployment', text: 'Deployed v1.0'
    }
}
```

**Claude's Actions:**
1. Recognize `nexusArtifactUploader` and `datadogEvent` are not in common_plugins.md
2. Use Context7: `mcp__context7__resolve-library-id` with "jenkinsci nexus-artifact-uploader"
3. If not found, WebSearch: "Jenkins nexus artifact uploader plugin documentation"
4. Provide guidance: "The nexusArtifactUploader step requires credentialsId for authentication..."

## Reference Documentation

The skill includes comprehensive reference documentation:

- **declarative_syntax.md**: Complete Declarative pipeline syntax reference
- **scripted_syntax.md**: Scripted pipeline and Groovy patterns
- **best_practices.md**: Comprehensive best practices guide from official Jenkins docs
- **common_plugins.md**: Documentation for popular plugins (git, docker, kubernetes, credentials, etc.)

## Validation Rules

### Syntax Issues
- Missing required sections (agent, stages, steps)
- Invalid section names or misplaced directives
- Groovy syntax errors
- Missing braces, quotes, or brackets
- Semicolons at end of lines (unnecessary in Jenkins pipelines)

### Best Practices
- **Combine Shell Commands**: Use single `sh` step with multiple commands instead of multiple `sh` steps
- **Credential Management**: Use `credentials()` or `withCredentials`, never hardcode secrets
- **Agent Operations**: Perform heavy operations on agents, not controller
- **Parallel Execution**: Use `parallel` for independent stages
- **Error Handling**: Wrap critical sections in try-catch blocks
- **Timeouts**: Define timeouts in options to prevent hung builds
- **Clean Workspace**: Clean workspace before/after builds

### Variable Usage
- Proper variable declaration and scoping
- Correct interpolation syntax (`${VAR}` vs `$VAR`)
- Undefined variable detection
- Environment variable usage

### Security
- No hardcoded passwords, API keys, or tokens
- Proper use of Jenkins Credentials Manager
- Secrets management best practices
- Role-based access control recommendations

## Error Reporting

Validation results include:
- **Line numbers** for each issue
- **Severity levels**: Error, Warning, Info
- **Descriptions**: Clear explanation of the issue
- **Suggestions**: How to fix the problem
- **References**: Links to documentation

### Example Output
```
ERROR [Line 5]: Missing required section 'agent'
  → Add 'agent any' or specific agent configuration at top level

WARNING [Line 12]: Multiple consecutive 'sh' steps detected
  → Combine into single sh step with triple-quoted string
  → See: best_practices.md#combine-shell-commands

INFO [Line 23]: Consider using parallel execution for independent stages
  → See: references/declarative_syntax.md#parallel-stages
```

## Usage Instructions

When a user provides a Jenkinsfile for validation:

1. **Run the main validation script** (recommended - handles everything automatically):
   ```bash
   bash scripts/validate_jenkinsfile.sh <path-to-jenkinsfile>
   ```
   This single command auto-detects pipeline type, runs syntax validation, security scan, and best practices check.

2. **Optionally read the Jenkinsfile** using the Read tool if you need to:
   - Understand the pipeline structure before validation
   - Provide context-specific advice
   - Identify specific plugins being used

3. **After validation, scan for unknown plugins** (Claude's responsibility):
   - Review the validation output for any unrecognized step names
   - Check `references/common_plugins.md` first for documentation
   - If not found, use Context7 MCP: `mcp__context7__resolve-library-id` with query "jenkinsci <plugin-name>"
   - If still not found, use WebSearch: "Jenkins <plugin-name> plugin documentation"
   - Provide usage guidance based on found documentation

4. **Report results** with line numbers, severity, and actionable suggestions

5. **Provide inline fix suggestions** when errors are found (do not use AskUserQuestion - include corrected code snippets directly in the response)

## Common Validation Scenarios

### Scenario 1: Validate Declarative Pipeline
```markdown
User: "Validate my Jenkinsfile"
1. Read the Jenkinsfile
2. Detect type: Declarative (starts with 'pipeline {')
3. Run: bash scripts/validate_declarative.sh Jenkinsfile
4. Run: bash scripts/best_practices.sh Jenkinsfile
5. Report results with suggestions
```

### Scenario 2: Validate with Unknown Plugin
```markdown
User: "Check this pipeline with custom plugin steps"
1. Read Jenkinsfile
2. Run validation
3. Detect unknown step (e.g., 'customDeploy')
4. Search context7 for plugin docs
5. If not found, web search "Jenkins custom deploy plugin"
6. Validate plugin usage against found documentation
7. Report results
```

### Scenario 3: Security Audit
```markdown
User: "Check for security issues in my pipeline"
1. Read Jenkinsfile
2. Run: bash scripts/common_validation.sh check_credentials Jenkinsfile
3. Scan for hardcoded secrets, passwords, API keys
4. Check credential management best practices
5. Report security findings with fix suggestions
```

## Tools Available

- **Bash**: Execute validation scripts
- **Read**: Read Jenkinsfile content
- **Grep**: Search for patterns in pipeline files
- **WebSearch**: Find plugin documentation online
- **Context7 MCP**: Access Jenkins and plugin documentation
- **WebFetch**: Retrieve specific documentation pages

## Best Practice Examples

### Good: Combined Shell Commands
```groovy
sh '''
  echo "Building..."
  mkdir build
  ./gradlew build
  echo "Build complete"
'''
```

### Bad: Multiple Shell Steps
```groovy
sh 'echo "Building..."'
sh 'mkdir build'
sh './gradlew build'
sh 'echo "Build complete"'
```

### Good: Credential Management
```groovy
withCredentials([string(credentialsId: 'api-key', variable: 'API_KEY')]) {
  sh 'curl -H "Authorization: Bearer $API_KEY" ...'
}
```

### Bad: Hardcoded Credentials
```groovy
sh 'curl -H "Authorization: Bearer abc123xyz" ...'
```

## Additional Capabilities

- **Dry-run Testing**: Validate without Jenkins server (all validation is local)
- **Plugin Version Checking**: Warn about deprecated plugin versions
- **Performance Analysis**: Identify potential performance bottlenecks
- **Compliance Checking**: Validate against organizational standards
- **Multi-file Support**: Validate multiple Jenkinsfiles in a directory

## References

- Official Jenkins Pipeline Syntax: https://www.jenkins.io/doc/book/pipeline/syntax/
- Pipeline Development Tools: https://www.jenkins.io/doc/book/pipeline/development/
- Pipeline Best Practices: https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/
- Jenkins Plugins: https://plugins.jenkins.io/

## Automatic Actions

When this skill is invoked:
1. Always validate syntax first (errors block execution)
2. Then check best practices (warnings for improvement)
3. Look up unknown plugins automatically
4. Provide actionable suggestions with every issue
5. Reference documentation files for detailed guidance

## Troubleshooting

### Common Issues

**Issue: "Best practices check shows false negatives"**
- **Cause**: Comment stripping may interfere with pattern detection
- **Solution**: update to latest version

**Issue: "Syntax validation passes but pipeline fails on Jenkins"**
- **Explanation**: Local validation catches structural issues but cannot verify:
  - Plugin availability
  - Agent/node availability
  - Credential existence
  - Network connectivity
- **Solution**: Validate on Jenkins using Replay feature or Pipeline Unit Testing Framework

**Issue: "Security scan shows passed but best practices finds credentials"**
- **Solution**: security scan now properly detects all credential patterns

**Issue: "Scripts not executable"**
- **Solution**: Run `chmod +x scripts/*.sh`

### Debug Mode

Enable verbose output for troubleshooting:

```bash
# Run with bash debug mode
bash -x scripts/validate_jenkinsfile.sh Jenkinsfile

# Check individual validator output
bash scripts/validate_declarative.sh Jenkinsfile
bash scripts/best_practices.sh Jenkinsfile
bash scripts/common_validation.sh check_credentials Jenkinsfile
```

## Limitations

- **No Jenkins Server Required**: All validation is local (no live testing)
- **Plugin Steps**: Cannot fully validate custom plugin steps without documentation
- **Runtime Behavior**: Cannot detect runtime issues (permissions, network, etc.)
- **Complex Groovy**: Advanced Groovy constructs may not be fully validated
- **Shared Libraries**: Remote shared libraries are not fetched or validated