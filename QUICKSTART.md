# Quickstart: 5-minute DevOps skill-pack loop

This walkthrough installs the plugin in Claude Code, generates a tiny Bash
utility with one generator skill, then validates it with the matching validator.

## 1. Install the plugin

In Claude Code, add this marketplace and install the plugin:

```bash
/plugin marketplace add akin-ozer/cc-devops-skills
```

```bash
/plugin install devops-skills@akin-ozer
```

Restart Claude Code if it asks you to reload plugins.

## 2. Invoke a generator skill

Create a small script with `bash-script-generator`. Paste this into Claude Code:

```text
Use bash-script-generator to create scripts/hello-devops.sh.
Requirements:
- Bash script with strict mode.
- Accept an optional name argument, defaulting to "DevOps".
- Print "hello, <name>" to stdout.
- Include usage text for -h and --help.
- Validate the script after generating it.
```

When the skill finishes, confirm the file exists:

```bash
test -f scripts/hello-devops.sh && sed -n '1,120p' scripts/hello-devops.sh
```

Run the generated script:

```bash
bash scripts/hello-devops.sh Codex
```

## 3. Invoke a validator skill

Validate the generated script with `bash-script-validator`. Paste this into
Claude Code:

```text
Use bash-script-validator to validate scripts/hello-devops.sh.
Apply fixes if needed, then rerun validation until it passes.
```

For a direct local check, you can also run the validator script from this repo:

```bash
cd devops-skills-plugin/skills/bash-script-validator
bash scripts/validate.sh ../../../scripts/hello-devops.sh
```

You have completed the core loop: install plugin, generate an artifact, validate
the artifact, and iterate on any findings.
