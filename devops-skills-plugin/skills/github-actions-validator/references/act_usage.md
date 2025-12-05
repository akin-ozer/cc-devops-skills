# Act (nektos/act) - Usage Reference

Act is a tool that allows you to run your GitHub Actions locally, providing fast feedback and acting as a local task runner.

## Installation

```bash
# Install act using the official script
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/nektos/act/master/install.sh | bash

# Or use the skill's installation script
bash scripts/install_tools.sh
```

## Core Commands

### List Workflows

List all available workflows in the repository:

```bash
act -l
```

List workflows for a specific event:

```bash
act -l pull_request
act -l push
act -l workflow_dispatch
```

### Dry Run (No Execution)

Validate workflows without executing them, useful for inspection and validation:

```bash
act -n
# or (long form)
act --dryrun
```

This performs a dry run that:
- Parses all workflow files
- Validates syntax
- Shows what would be executed
- Does NOT actually run any jobs
- Returns exit code 0 on success, non-zero on errors

**Important for Validation:** The dry-run mode is perfect for validating workflow syntax before pushing to GitHub.

### Run Workflows

Run the default workflow:

```bash
act
```

Run workflows for a specific event:

```bash
act push
act pull_request
act workflow_dispatch
```

Run a specific job:

```bash
act -j <job-id>
```

Run a specific workflow file:

```bash
act -W .github/workflows/ci.yml
```

## Common Use Cases

### 1. Validate Workflow Syntax

Use dry run to check if workflows parse correctly:

```bash
act -n
```

If there are syntax errors, act will report them immediately.

### 2. Test Workflows Locally

Before pushing to GitHub, test workflows locally:

```bash
# Test push event workflows
act push

# Test pull request workflows
act pull_request
```

### 3. Debug Workflow Issues

Run workflows with verbose output:

```bash
act -v
```

### 4. List Available Events

See which events have workflows configured:

```bash
act -l
```

Output format:
```
Stage  Job ID  Job name  Workflow name  Workflow file  Events
0      build   build     CI             ci.yml         push,pull_request
0      test    test      CI             ci.yml         push,pull_request
```

## Advanced Options

### Container Architecture

Ensure consistent platform behavior across different machines:

```bash
act --container-architecture linux/amd64
```

This is especially important on ARM-based Macs (M1/M2/M3) to ensure workflows run in the same environment as GitHub's x64 runners.

### Using Specific Docker Images

Act uses Docker containers to run jobs. Specify custom images:

```bash
act -P ubuntu-latest=node:16-buster
```

### Configuration File

Create `.actrc` file in your project or home directory to set default options:

```bash
# .actrc
--container-architecture=linux/amd64
--action-offline-mode
```

Options are loaded in this order:
1. XDG spec `.actrc`
2. HOME directory `.actrc`
3. Current directory `.actrc`
4. CLI arguments

### Passing Secrets

Provide secrets for testing:

```bash
act -s GITHUB_TOKEN=ghp_xxx
```

Or use a secrets file:

```bash
act --secret-file .secrets
```

### Environment Variables

Set environment variables:

```bash
act --env MY_VAR=value
```

### Input Variables (for workflow_dispatch)

Pass input variables:

```bash
act workflow_dispatch --input myInput=myValue
```

## Limitations

Be aware of act's limitations:

1. **Not 100% Compatible**: Some GitHub Actions features may not work exactly as on GitHub
2. **Docker Required**: act requires Docker to be installed and running
3. **Network Actions**: Some actions that interact with GitHub's API may fail
4. **Runner Images**: Default runner images may differ from GitHub's hosted runners
5. **Secrets**: Local testing requires manually providing secrets

## Exit Codes

- `0`: Success - all jobs passed
- `1`: Failure - at least one job failed
- `2`: Error - workflow parsing or execution error

## Best Practices for Validation

1. **Always run dry-run first**: `act -n` to catch syntax errors
2. **Test specific events**: Don't run all workflows, target the event you care about
3. **Use verbose mode for debugging**: `act -v` when troubleshooting
4. **Check Docker availability**: Ensure Docker is running before using act
5. **Consider limitations**: Not all features work locally - use for syntax and basic logic validation

## Troubleshooting

### Issue: "Cannot connect to Docker daemon"

**Solution**: Start Docker Desktop or Docker daemon

### Issue: "Workflow file not found"

**Solution**: Ensure you're in the repository root or use `-W` to specify the workflow file path

### Issue: "Action not found"

**Solution**: Some actions may not be available locally. Use `-P` to specify alternative Docker images or skip the problematic action for validation purposes

### Issue: "Out of disk space"

**Solution**: Clean up Docker images: `docker system prune -a`
