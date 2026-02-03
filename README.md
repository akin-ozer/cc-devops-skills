# DevOps Skills for Claude Code

A comprehensive collection of Claude Code skills for DevOps engineers, providing generators and validators for infrastructure automation, CI/CD pipelines, container orchestration, and observability tooling.

[![Mentioned in Awesome Claude Code](https://awesome.re/mentioned-badge-flat.svg)](https://github.com/hesreallyhim/awesome-claude-code)
## What are Claude Code Skills?

Skills are reusable prompt templates that help Claude provide expert guidance on specific topics. When you invoke a skill, Claude assumes the role of an expert in that domain and provides detailed, actionable advice with automatic validation.

## Available Skills (31 skills)

### Ansible (2 skills)
| Skill | Description |
|-------|-------------|
| `ansible-generator` | Generate production-ready Ansible playbooks, roles, tasks, and inventory files following best practices |
| `ansible-validator` | Validate, lint, and test Ansible playbooks and roles using ansible-lint and syntax checks |

### Azure Pipelines (2 skills)
| Skill | Description |
|-------|-------------|
| `azure-pipelines-generator` | Generate best practice Azure DevOps Pipelines for CI/CD workflows |
| `azure-pipelines-validator` | Validate, lint, and secure Azure DevOps Pipeline configurations |

### Bash Scripts (2 skills)
| Skill | Description |
|-------|-------------|
| `bash-script-generator` | Generate best practice bash scripts with proper error handling and portability |
| `bash-script-validator` | Validate, lint, and optimize bash and shell scripts for syntax and security |

### Docker (2 skills)
| Skill | Description |
|-------|-------------|
| `dockerfile-generator` | Generate production-ready Dockerfiles with multi-stage builds and security hardening |
| `dockerfile-validator` | Validate Dockerfiles using hadolint and Checkov for security and best practices |

### Fluent Bit (2 skills)
| Skill | Description |
|-------|-------------|
| `fluentbit-generator` | Generate Fluent Bit configurations for log collection and forwarding pipelines |
| `fluentbit-validator` | Validate Fluent Bit configurations for syntax, security, and best practices |

### GitHub Actions (2 skills)
| Skill | Description |
|-------|-------------|
| `github-actions-generator` | Generate GitHub Actions workflows and custom actions (composite, Docker, JavaScript) |
| `github-actions-validator` | Validate GitHub Actions workflows using actionlint and test with act |

### GitLab CI (2 skills)
| Skill | Description |
|-------|-------------|
| `gitlab-ci-generator` | Generate GitLab CI/CD pipelines following best practices |
| `gitlab-ci-validator` | Validate, lint, and secure GitLab CI/CD pipeline configurations |

### Helm (2 skills)
| Skill | Description |
|-------|-------------|
| `helm-generator` | Generate Helm charts with proper templating, values, and chart structure |
| `helm-validator` | Validate and lint Helm charts with automatic CRD documentation lookup |

### Jenkins (2 skills)
| Skill | Description |
|-------|-------------|
| `jenkinsfile-generator` | Generate Jenkinsfiles for Declarative and Scripted pipeline syntaxes |
| `jenkinsfile-validator` | Validate and lint Jenkinsfile pipelines for syntax and best practices |

### Kubernetes (3 skills)
| Skill | Description |
|-------|-------------|
| `k8s-generator` | Generate Kubernetes YAML manifests with automatic CRD documentation lookup |
| `k8s-yaml-validator` | Validate Kubernetes manifests using kubeconform and yamllint |
| `k8s-debug` | Debug Kubernetes cluster issues with systematic troubleshooting workflows |

### Logging & Observability (3 skills)
| Skill | Description |
|-------|-------------|
| `logql-generator` | Generate LogQL queries for Loki log analysis and alerting |
| `loki-config-generator` | Generate Loki configuration files for log aggregation |
| `promql-generator` | Generate PromQL queries for Prometheus monitoring and alerting |

### Makefiles (2 skills)
| Skill | Description |
|-------|-------------|
| `makefile-generator` | Generate best practice Makefiles for build automation |
| `makefile-validator` | Validate, lint, and optimize Makefiles for syntax and best practices |

### PromQL (1 skill)
| Skill | Description |
|-------|-------------|
| `promql-validator` | Validate PromQL queries for syntax and best practices |

### Terraform (2 skills)
| Skill | Description |
|-------|-------------|
| `terraform-generator` | Generate Terraform configurations following best practices |
| `terraform-validator` | Validate Terraform configurations with fmt, validate, and tflint |

### Terragrunt (2 skills)
| Skill | Description |
|-------|-------------|
| `terragrunt-generator` | Generate Terragrunt configurations for multi-environment deployments |
| `terragrunt-validator` | Validate Terragrunt configurations and DRY patterns |

## Installation

### From Plugin Marketplace (Recommended)

Add this repository as a Claude Code plugin marketplace and install the skills:

```bash
# Add the marketplace
/plugin marketplace add akin-ozer/cc-devops-skills

# Install the plugin
/plugin install devops-skills@akin-ozer
```

Or browse available plugins interactively with `/plugin`.

### Team Installation

To automatically install for your team, add to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "devops-skills": {
      "source": {
        "source": "github",
        "repo": "akin-ozer/cc-devops-skills"
      }
    }
  }
}
```

When team members trust the repository folder, Claude Code automatically installs the marketplace.

Now available for Codex desktop 🎉

```
$skill-installer install https://github.com/akin-ozer/cc-devops-skills/tree/main/devops-skills-plugin/skills
```

## How to Use

### Invoking a Skill

Simply ask Claude to use a skill by name:

```
Use the dockerfile-generator skill to create a Dockerfile for my Node.js application
```

Or ask Claude to validate an existing file:

```
Validate my terraform configuration using the terraform-validator skill
```

### Generator + Validator Workflow

Most skills come in pairs (generator + validator). When you use a generator skill, it automatically validates the output:

1. **Generator creates** the resource following best practices
2. **Validator checks** for syntax errors, security issues, and best practices
3. **Generator fixes** any validation errors
4. **Final output** is production-ready and validated

## Skill Categories

### By Function
- **Generators**: Create new resources from scratch following best practices
- **Validators**: Validate, lint, and secure existing resources
- **Debug/Troubleshooting**: Diagnose and fix issues in running systems

### By Technology Area

```
Infrastructure as Code
├── Terraform (generator, validator)
├── Terragrunt (generator, validator)
└── Ansible (generator, validator)

Container & Orchestration
├── Dockerfile (generator, validator)
├── Kubernetes (generator, validator, debug)
└── Helm (generator, validator)

CI/CD Pipelines
├── GitHub Actions (generator, validator)
├── GitLab CI (generator, validator)
├── Jenkins (generator, validator)
└── Azure Pipelines (generator, validator)

Observability
├── PromQL (generator, validator)
├── LogQL (generator)
├── Fluent Bit (generator, validator)
└── Loki Config (generator)

Build & Scripting
├── Makefile (generator, validator)
└── Bash Script (generator, validator)
```

### By Experience Level

| Level | Skills |
|-------|--------|
| **Beginner-friendly** | dockerfile-generator, bash-script-generator, makefile-generator |
| **Intermediate** | terraform-generator, ansible-generator, github-actions-generator, k8s-generator |
| **Advanced** | helm-generator, terragrunt-generator, k8s-debug, promql-generator |

## Key Features

### Automatic Validation
All generator skills automatically validate their output using the corresponding validator skill, ensuring production-ready results.

### Version-Aware Documentation
Skills automatically fetch up-to-date documentation for:
- Custom Resource Definitions (CRDs) in Kubernetes
- Terraform providers and modules
- Ansible collections and modules
- CI/CD actions and plugins

### Best Practices Enforcement
Each skill enforces domain-specific best practices:
- Security hardening
- Resource optimization
- Naming conventions
- Idempotency guarantees

## Skill Structure

Each skill in `.claude/skills/` contains:

```
skill-name/
├── SKILL.md           # Main skill prompt with instructions
├── references/        # Best practices and troubleshooting guides
├── scripts/           # Helper scripts for validation
├── assets/            # Templates and configuration files
└── test/              # Test files for validation
```

## Contributing

These skills are designed to evolve with DevOps best practices. Contributions welcome:
- Add new skills for emerging technologies
- Update existing skills with new best practices
- Improve validation scripts and references
- Add test cases for better coverage

## Best Practices for Using Skills

1. **Be specific**: Provide context about your environment, requirements, and constraints
2. **Share files**: Upload relevant configuration files for Claude to review
3. **Ask follow-ups**: Skills are starting points - ask for clarification or alternatives
4. **Combine skills**: Use generators and validators together for best results
5. **Iterate**: Refine the output by providing feedback

## Requirements

### MCP Servers (Recommended)

Skills leverage MCP (Model Context Protocol) servers for enhanced functionality:

| MCP Server | Purpose | Used By |
|------------|---------|---------|
| **Context7** | Fetch up-to-date documentation for CRDs, Terraform providers, Ansible collections | k8s-generator, helm-generator, terraform-generator, ansible-generator |

Context7 enables skills to automatically look up version-aware documentation for custom resources, ensuring generated configurations are accurate and up-to-date.

### CLI Tools by Skill

#### Infrastructure as Code

| Tool | Skills | Installation |
|------|--------|--------------|
| `terraform` | terraform-generator, terraform-validator | `brew install terraform` |
| `tflint` | terraform-validator | `brew install tflint` |
| `terragrunt` | terragrunt-generator, terragrunt-validator | `brew install terragrunt` |
| `checkov` | terraform-validator, dockerfile-validator | `pip install checkov` (Python 3.9+) |
| `ansible-lint` | ansible-generator, ansible-validator | `pip install ansible-lint` |
| `ansible` | ansible-validator | `pip install ansible` |

#### Container & Kubernetes

| Tool | Skills | Installation |
|------|--------|--------------|
| `hadolint` | dockerfile-validator | `brew install hadolint` |
| `helm` | helm-generator, helm-validator | `brew install helm` (v3+) |
| `kubeconform` | k8s-yaml-validator, helm-validator | `brew install kubeconform` |
| `kubectl` | k8s-debug, k8s-yaml-validator | `brew install kubectl` |
| `yamllint` | k8s-yaml-validator, helm-validator, ansible-validator | `pip install yamllint` |

#### CI/CD Pipelines

| Tool | Skills | Installation |
|------|--------|--------------|
| `actionlint` | github-actions-validator | `brew install actionlint` |
| `act` | github-actions-validator | `brew install act` |

#### Scripting & Build

| Tool | Skills | Installation |
|------|--------|--------------|
| `shellcheck` | bash-script-validator | `brew install shellcheck` |
| `make` | makefile-validator | Usually pre-installed |

#### Observability

| Tool | Skills | Installation |
|------|--------|--------------|
| `promtool` | promql-validator | Part of Prometheus: `brew install prometheus` |
| `fluent-bit` | fluentbit-validator | `brew install fluent-bit` (optional, for dry-run) |

### Optional Tools

These tools provide additional functionality but are not strictly required:

| Tool | Purpose | Installation |
|------|---------|--------------|
| `yq` | YAML manipulation and querying | `brew install yq` |
| `helm-diff` | Preview Helm upgrade changes | `helm plugin install https://github.com/databus23/helm-diff` |
| `molecule` | Ansible role testing | `pip install molecule` |
| `docker` | Required for `act` to test GitHub Actions locally | `brew install docker` |

### Python Requirements

Many validation scripts require Python:
- **Python 3.8+** - Required for most validation scripts
- **Python 3.9+** - Required for Checkov

### Quick Install (macOS with Homebrew)

```bash
# Core tools
brew install terraform tflint terragrunt helm kubeconform kubectl yamllint
brew install hadolint actionlint act shellcheck prometheus

# Python tools (use pipx for isolation)
pipx install ansible-lint checkov yamllint

# Optional
brew install yq fluent-bit
helm plugin install https://github.com/databus23/helm-diff
```

### Quick Install (Linux)

```bash
# Python tools
pip install ansible-lint checkov yamllint

# Other tools - see individual tool documentation for Linux installation
# Most tools provide binary releases on GitHub
```

## License

Apache 2.0
