# Environment Variables

This repository is a DevOps skill pack, so most environment variables are read by
individual skill scripts, test fixtures, or the GitHub Action wrapper. Variables
shown as optional use the listed default when unset. Template and reference files
that only demonstrate environment variables for generated user artifacts are not
listed unless a repository script reads them directly.

## GitHub Action wrapper

| Variable | Required | Default | Description | Found in |
|---|---:|---|---|---|
| `GITHUB_OUTPUT` | Required in GitHub Actions | Provided by runner | File path used by the composite action to write step outputs. | `action.yml` |
| `INJECT_DEVOPS_SKILLS` | Optional | `inputs.inject_devops_skills` | Internal environment bridge that controls whether default DevOps marketplace and plugin entries are prepended. | `action.yml` |
| `DEVOPS_MARKETPLACE_URL` | Optional | `inputs.devops_marketplace_url` | Internal environment bridge for the default marketplace URL. | `action.yml` |
| `DEVOPS_PLUGIN_NAME` | Optional | `inputs.devops_plugin_name` | Internal environment bridge for the default plugin name. | `action.yml` |
| `USER_PLUGIN_MARKETPLACES` | Optional | `inputs.plugin_marketplaces` | Internal environment bridge for user-supplied marketplace entries. | `action.yml` |
| `USER_PLUGINS` | Optional | `inputs.plugins` | Internal environment bridge for user-supplied plugin entries. | `action.yml` |

## Wrapper compatibility script

| Variable | Required | Default | Description | Found in |
|---|---:|---|---|---|
| `UPSTREAM_REF` | Optional | `v1` | Upstream `anthropics/claude-code-action` ref used for compatibility checks. | `scripts/check_upstream_action_surface.sh` |
| `UPSTREAM_ACTION_URL` | Optional | `https://raw.githubusercontent.com/anthropics/claude-code-action/${UPSTREAM_REF}/action.yml` | URL of the upstream action metadata to compare against. | `scripts/check_upstream_action_surface.sh` |
| `LOCAL_ACTION_PATH` | Optional | `action.yml` | Local wrapper action metadata file to compare against upstream. | `scripts/check_upstream_action_surface.sh` |

## Shared shell and tool environment

| Variable | Required | Default | Description | Found in |
|---|---:|---|---|---|
| `PATH` | Optional | Current process `PATH` | Used by shell and Python scripts to locate external tools such as `kubectl`, `docker`, `shellcheck`, `terraform`, and validators; some tests override it to simulate missing tools. | Multiple scripts and tests |
| `HOME` | Optional | Current process `HOME` | Used to build default cache/install paths for Terraform validator helpers and in Jenkinsfile validator example fixtures. | `devops-skills-plugin/skills/terraform-validator/scripts/extract_tf_info_wrapper.sh`, `devops-skills-plugin/skills/terraform-validator/scripts/install_checkov.sh`, Jenkinsfile examples |
| `TMPDIR` | Optional | `/tmp` | Base directory for temporary virtual environments and test scratch directories. | `devops-skills-plugin/skills/makefile-validator/scripts/validate_makefile.sh`, `devops-skills-plugin/skills/makefile-validator/scripts/test_validate.sh`, `devops-skills-plugin/skills/dockerfile-validator/scripts/dockerfile-validate.sh` |
| `CI` | Optional | unset | Enables stricter ShellCheck behavior in CI-oriented validation scripts when explicit ShellCheck options are not provided. | `devops-skills-plugin/skills/bash-script-validator/scripts/validate.sh`, `devops-skills-plugin/skills/bash-script-generator/scripts/run_ci_checks.sh`, `devops-skills-plugin/skills/terragrunt-validator/scripts/run_ci_checks.sh` |

## Skill runtime variables

| Variable | Required | Default | Description | Found in |
|---|---:|---|---|---|
| `K8S_REQUEST_TIMEOUT` | Optional | `15s` | Request timeout passed to `kubectl` by Kubernetes diagnostic scripts. | `devops-skills-plugin/skills/k8s-debug/scripts/cluster_health.sh`, `devops-skills-plugin/skills/k8s-debug/scripts/network_debug.sh`, `devops-skills-plugin/skills/k8s-debug/scripts/pod_diagnostics.py` |
| `RUN_LOKI_RUNTIME_TESTS` | Optional | `auto` | Controls whether LogQL generator Loki runtime integration tests run, skip, or require Docker. | `devops-skills-plugin/skills/logql-generator/tests/test_loki_runtime_integration.py`, `devops-skills-plugin/skills/logql-generator/scripts/run_regression_checks.sh` |
| `LOKI_IMAGE` | Optional | `grafana/loki:3.6.2` | Docker image used for LogQL generator Loki runtime integration tests. | `devops-skills-plugin/skills/logql-generator/tests/test_loki_runtime_integration.py` |
| `LOKI_STARTUP_TIMEOUT_SECONDS` | Optional | `60` | Maximum wait for the ephemeral Loki runtime to become ready. | `devops-skills-plugin/skills/logql-generator/tests/test_loki_runtime_integration.py` |
| `LOKI_QUERY_TIMEOUT_SECONDS` | Optional | `25` | HTTP query timeout used by Loki runtime integration tests. | `devops-skills-plugin/skills/logql-generator/tests/test_loki_runtime_integration.py` |
| `NO_COLOR` | Optional | unset | Disables colored output in the Makefile validator. | `devops-skills-plugin/skills/makefile-validator/scripts/validate_makefile.sh` |
| `MBAKE_SKIP_INSTALL` | Optional | `0` | Skips mbake installation and runs Makefile validator fallback checks only. | `devops-skills-plugin/skills/makefile-validator/scripts/validate_makefile.sh` |
| `JENKINSFILE` | Optional | unset | Jenkinsfile path fallback when no positional path is parsed by the Jenkinsfile validator. | `devops-skills-plugin/skills/jenkinsfile-validator/scripts/validate_jenkinsfile.sh` |
| `FORCE_TEMP_INSTALL` | Optional | `false` | Forces Dockerfile validator temporary tool installation mode, mainly for cleanup testing. | `devops-skills-plugin/skills/dockerfile-validator/scripts/dockerfile-validate.sh` |
| `VALIDATOR_REQUIRE_SHELLCHECK` | Optional | derived from `CI` | Forces Bash script validator ShellCheck requirement on (`1`) or off (`0`). | `devops-skills-plugin/skills/bash-script-validator/scripts/validate.sh` |
| `VALIDATOR_SHELLCHECK_MODE` | Optional | `auto` | Selects Bash script validator ShellCheck provider: `auto`, `system`, `wrapper`, or `disabled`. | `devops-skills-plugin/skills/bash-script-validator/scripts/validate.sh` |
| `VALIDATOR_DISABLE_SHELLCHECK` | Optional | `0` | Disables the Bash script validator ShellCheck stage when set to `1`. | `devops-skills-plugin/skills/bash-script-validator/scripts/validate.sh` |
| `SHELLCHECK_BIN` | Optional | `shellcheck` | Overrides the ShellCheck executable used by bash-script-generator CI checks. | `devops-skills-plugin/skills/bash-script-generator/scripts/run_ci_checks.sh` |
| `STRICT_SHELLCHECK` | Optional | `false` | Requires ShellCheck in Dockerfile validator and Terraform generator test runners. | `devops-skills-plugin/skills/dockerfile-validator/scripts/test_validate.sh`, `devops-skills-plugin/skills/terraform-generator/scripts/run_ci_checks.sh` |
| `SKIP_PLAN` | Optional | `false` | Skips Terragrunt/Terraform plan validation. | `devops-skills-plugin/skills/terragrunt-validator/scripts/validate_terragrunt.sh` |
| `SKIP_SECURITY` | Optional | `false` | Skips Terragrunt security scanning. | `devops-skills-plugin/skills/terragrunt-validator/scripts/validate_terragrunt.sh` |
| `SKIP_LINT` | Optional | `false` | Skips Terragrunt linting. | `devops-skills-plugin/skills/terragrunt-validator/scripts/validate_terragrunt.sh` |
| `SKIP_INPUT_VALIDATION` | Optional | `false` | Skips Terragrunt HCL input validation. | `devops-skills-plugin/skills/terragrunt-validator/scripts/validate_terragrunt.sh` |
| `SKIP_INIT` | Optional | `false` | Skips Terragrunt initialization. | `devops-skills-plugin/skills/terragrunt-validator/scripts/validate_terragrunt.sh` |
| `SKIP_BACKEND_INIT` | Optional | `false` | Skips backend initialization during Terragrunt validation. | `devops-skills-plugin/skills/terragrunt-validator/scripts/validate_terragrunt.sh` |
| `SOFT_FAIL_SECURITY` | Optional | `false` | Reports Terragrunt security findings without failing the overall run. | `devops-skills-plugin/skills/terragrunt-validator/scripts/validate_terragrunt.sh` |
| `SECURITY_SCANNER` | Optional | `auto` | Selects Terragrunt security scanner preference: `trivy`, `tfsec`, `checkov`, or `auto`. | `devops-skills-plugin/skills/terragrunt-validator/scripts/validate_terragrunt.sh` |
| `TG_STRICT_MODE` | Optional | `false` | Adds Terragrunt `--strict-mode` when set to `true`. | `devops-skills-plugin/skills/terragrunt-validator/scripts/validate_terragrunt.sh` |
| `XDG_CACHE_HOME` | Optional | `$HOME/.cache` | Base cache directory for Terraform validator's `python-hcl2` virtual environment. | `devops-skills-plugin/skills/terraform-validator/scripts/extract_tf_info_wrapper.sh` |
| `TF_VALIDATOR_HCL2_VENV` | Optional | `$XDG_CACHE_HOME/terraform-validator/hcl2-venv` | Explicit virtual environment path for Terraform HCL parsing dependencies. | `devops-skills-plugin/skills/terraform-validator/scripts/extract_tf_info_wrapper.sh` |
| `CHECKOV_INSTALL_DIR` | Optional | `$HOME/.local/checkov-venv` | Install directory for the Terraform validator Checkov virtual environment and generated wrapper. | `devops-skills-plugin/skills/terraform-validator/scripts/install_checkov.sh` |

## Generator script variables

| Variable | Required | Default | Description | Found in |
|---|---:|---|---|---|
| `JAVA_VERSION` | Optional | `21` | Java base image version for generated Java Dockerfiles. | `devops-skills-plugin/skills/dockerfile-generator/scripts/generate_java.sh` |
| `NODE_VERSION` | Optional | `20` | Node.js base image version for generated Node.js Dockerfiles. | `devops-skills-plugin/skills/dockerfile-generator/scripts/generate_nodejs.sh` |
| `GO_VERSION` | Optional | `1.21` | Go base image version for generated Go Dockerfiles. | `devops-skills-plugin/skills/dockerfile-generator/scripts/generate_golang.sh` |
| `PYTHON_VERSION` | Optional | `3.12` | Python base image version for generated Python Dockerfiles. | `devops-skills-plugin/skills/dockerfile-generator/scripts/generate_python.sh` |
| `PORT` | Optional | `8080`, `3000`, or `8000` depending on generator | Exposed application port in generated Dockerfiles. | Dockerfile generator scripts |
| `OUTPUT_FILE` | Optional | `Dockerfile` or `.dockerignore` depending on generator | Destination file for generated Dockerfiles or `.dockerignore`. | Dockerfile generator scripts |
| `BUILD_TOOL` | Optional | `maven` | Java build tool for generated Java Dockerfiles. | `devops-skills-plugin/skills/dockerfile-generator/scripts/generate_java.sh` |
| `LANGUAGE` | Optional | `generic` | Language profile used for generated `.dockerignore` contents. | `devops-skills-plugin/skills/dockerfile-generator/scripts/generate_dockerignore.sh` |
| `APP_ENTRY` | Optional | `index.js` or `app.py` depending on generator | Legacy application entry point for generated Node.js or Python Dockerfiles. | `generate_nodejs.sh`, `generate_python.sh` |
| `ENTRY_CMD` | Optional | unset | Structured command entry point for generated Node.js or Python Dockerfiles. | `generate_nodejs.sh`, `generate_python.sh` |
| `BUILD_STAGE` | Optional | `false` | Enables multistage generation for Node.js Dockerfiles. | `devops-skills-plugin/skills/dockerfile-generator/scripts/generate_nodejs.sh` |
| `BINARY_NAME` | Optional | `app` | Binary name copied into generated Go Dockerfiles. | `devops-skills-plugin/skills/dockerfile-generator/scripts/generate_golang.sh` |
| `USE_DISTROLESS` | Optional | `true` | Selects distroless or Alpine final image for generated Go Dockerfiles. | `devops-skills-plugin/skills/dockerfile-generator/scripts/generate_golang.sh` |
| `SKILL_FILE` | Optional | `devops-skills-plugin/skills/terraform-generator/SKILL.md` | Terraform generator feature/version checker input skill file. | `devops-skills-plugin/skills/terraform-generator/scripts/check_feature_version_consistency.sh` |
| `BEST_PRACTICES_FILE` | Optional | `references/terraform_best_practices.md` | Terraform generator feature/version checker best-practices reference file. | `devops-skills-plugin/skills/terraform-generator/scripts/check_feature_version_consistency.sh` |
| `VERSIONS_FILE` | Optional | `assets/minimal-project/versions.tf` | Terraform generator feature/version checker Terraform versions file. | `devops-skills-plugin/skills/terraform-generator/scripts/check_feature_version_consistency.sh` |

## Test-only variables

| Variable | Required | Default | Description | Found in |
|---|---:|---|---|---|
| `MAKEFILE_VALIDATOR_TEST_SUITE` | Optional | `${TEST_SUITE:-offline}` | Selects Makefile validator regression test suite. | `devops-skills-plugin/skills/makefile-validator/scripts/test_validate.sh` |
| `TEST_SUITE` | Optional | `offline` | Backward-compatible fallback for Makefile validator test-suite selection. | `devops-skills-plugin/skills/makefile-validator/scripts/test_validate.sh` |
| `FAKE_SHELLCHECK_MODE` | Optional | `ok` | Controls fake ShellCheck behavior in Bash script validator regression tests. | `devops-skills-plugin/skills/bash-script-validator/scripts/test_validate.sh` |
| `KUBECTL_STUB_LOG` | Optional | `/dev/null` | Log path for stubbed `kubectl` calls in Kubernetes debug regression tests. | `devops-skills-plugin/skills/k8s-debug/tests/test_regressions.sh` |
| `K8S_STUB_CONTEXT_FAIL` | Optional | `0` | Makes the Kubernetes debug test `kubectl` stub fail context lookup. | `devops-skills-plugin/skills/k8s-debug/tests/test_regressions.sh` |
| `K8S_STUB_CAN_I_EXEC` | Optional | `yes` | Stubbed response for Kubernetes `auth can-i create pods/exec` checks. | `devops-skills-plugin/skills/k8s-debug/tests/test_regressions.sh` |
| `K8S_STUB_FAIL_NODE_LIST` | Optional | `0` | Makes the Kubernetes debug test `kubectl` stub fail node list calls. | `devops-skills-plugin/skills/k8s-debug/tests/test_regressions.sh` |
| `K8S_STUB_SA_FILES` | Optional | `present` | Controls whether service-account files appear present in network-debug tests. | `devops-skills-plugin/skills/k8s-debug/tests/test_regressions.sh` |
| `K8S_STUB_DNS_FAIL` | Optional | `0` | Makes DNS checks fail in Kubernetes network-debug tests. | `devops-skills-plugin/skills/k8s-debug/tests/test_regressions.sh` |
| `K8S_STUB_EXPECT_SECURE` | Optional | `0` | Asserts that Kubernetes network-debug tests use secure API requests. | `devops-skills-plugin/skills/k8s-debug/tests/test_regressions.sh` |
| `K8S_STUB_EXPECT_INSECURE` | Optional | `0` | Asserts that Kubernetes network-debug tests use insecure API requests. | `devops-skills-plugin/skills/k8s-debug/tests/test_regressions.sh` |
| `DOCKER_INFO_STUB_EXIT` | Optional | `0` | Exit code for stubbed `docker info` in GitHub Actions validator tests. | `devops-skills-plugin/skills/github-actions-validator/tests/test_validate_workflow.sh` |
| `ACT_LIST_STUB_EXIT` | Optional | `0` | Exit code for stubbed `act --list` in GitHub Actions validator tests. | `devops-skills-plugin/skills/github-actions-validator/tests/test_validate_workflow.sh` |
| `ACT_DRYRUN_STUB_EXIT` | Optional | `0` | Exit code for stubbed `act --dryrun` in GitHub Actions validator tests. | `devops-skills-plugin/skills/github-actions-validator/tests/test_validate_workflow.sh` |
| `ACT_STUB_EXIT` | Optional | `0` | Exit code for general stubbed `act` calls in GitHub Actions validator tests. | `devops-skills-plugin/skills/github-actions-validator/tests/test_validate_workflow.sh` |
| `ACTIONLINT_STUB_EXIT` | Optional | `0` | Exit code for stubbed `actionlint` in GitHub Actions validator tests. | `devops-skills-plugin/skills/github-actions-validator/tests/test_validate_workflow.sh` |
| `CHECKOV_STUB_EXIT` | Optional | `0` | Exit code for stubbed `checkov` in Terraform validator regression tests. | `devops-skills-plugin/skills/terraform-validator/tests/test_regression.sh` |
| `ANSIBLE_ROLES_PATH` | Optional | test fixture path | Role lookup path passed to `ansible-playbook` in Ansible generator regression tests. | `devops-skills-plugin/skills/ansible-generator/test/test_fixture_regressions.py` |
| `MOLECULE_DISTRO` | Optional | `rockylinux9` | Docker image distro used by the vendored Molecule fixture. | `devops-skills-plugin/skills/ansible-validator/test/roles/geerlingguy.mysql/molecule/default/molecule.yml` |
| `MOLECULE_DOCKER_COMMAND` | Optional | empty string | Docker command override used by the vendored Molecule fixture. | `devops-skills-plugin/skills/ansible-validator/test/roles/geerlingguy.mysql/molecule/default/molecule.yml` |
| `MOLECULE_PLAYBOOK` | Optional | `converge.yml` | Converge playbook override used by the vendored Molecule fixture. | `devops-skills-plugin/skills/ansible-validator/test/roles/geerlingguy.mysql/molecule/default/molecule.yml` |
