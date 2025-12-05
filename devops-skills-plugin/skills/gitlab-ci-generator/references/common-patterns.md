# GitLab CI/CD Common Patterns

This document provides ready-to-use patterns for common GitLab CI/CD scenarios. Use these patterns as starting points and customize them for your specific needs.

## Table of Contents

1. [Basic CI Pipeline Patterns](#basic-ci-pipeline-patterns)
2. [Docker Build and Push Patterns](#docker-build-and-push-patterns)
3. [Kubernetes Deployment Patterns](#kubernetes-deployment-patterns)
4. [Testing Patterns](#testing-patterns)
5. [Deployment Patterns](#deployment-patterns)
6. [Multi-Project Pipeline Patterns](#multi-project-pipeline-patterns)
7. [Parent-Child Pipeline Patterns](#parent-child-pipeline-patterns)
8. [Monorepo Patterns](#monorepo-patterns)
9. [Template and Reusability Patterns](#template-and-reusability-patterns)

---

## Basic CI Pipeline Patterns

### Pattern 1: Simple Three-Stage Pipeline

**Use case:** Basic projects with build, test, and deploy stages.

```yaml
stages:
  - build
  - test
  - deploy

variables:
  NODE_VERSION: "20"

build-job:
  stage: build
  image: node:${NODE_VERSION}-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour

test-job:
  stage: test
  image: node:${NODE_VERSION}-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
    policy: pull
  script:
    - npm ci
    - npm test

deploy-job:
  stage: deploy
  image: alpine:3.19
  script:
    - apk add --no-cache rsync openssh
    - rsync -avz dist/ $DEPLOY_SERVER:/var/www/html/
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  when: manual
```

### Pattern 2: Multi-Language Build Pipeline

**Use case:** Projects with multiple language components.

```yaml
stages:
  - build
  - test
  - deploy

build-frontend:
  stage: build
  image: node:20-alpine
  script:
    - cd frontend
    - npm ci
    - npm run build
  artifacts:
    paths:
      - frontend/dist/
    expire_in: 1 hour

build-backend:
  stage: build
  image: golang:1.22-alpine
  script:
    - cd backend
    - go build -o app
  artifacts:
    paths:
      - backend/app
    expire_in: 1 hour

test-frontend:
  stage: test
  image: node:20-alpine
  needs: [build-frontend]
  script:
    - cd frontend
    - npm ci
    - npm test

test-backend:
  stage: test
  image: golang:1.22-alpine
  needs: [build-backend]
  script:
    - cd backend
    - go test ./...
```

---

## Docker Build and Push Patterns

### Pattern 1: Docker Build with Multi-Stage

**Use case:** Building and pushing Docker images to GitLab Container Registry.

```yaml
stages:
  - build
  - push

variables:
  DOCKER_DRIVER: overlay2
  IMAGE_NAME: $CI_REGISTRY_IMAGE
  DOCKER_TLS_CERTDIR: "/certs"

build-docker-image:
  stage: build
  image: docker:24-dind
  services:
    - docker:24-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build
        --cache-from $IMAGE_NAME:latest
        --tag $IMAGE_NAME:$CI_COMMIT_SHORT_SHA
        --tag $IMAGE_NAME:latest
        --build-arg VERSION=$CI_COMMIT_SHORT_SHA
        .
    - docker push $IMAGE_NAME:$CI_COMMIT_SHORT_SHA
    - docker push $IMAGE_NAME:latest
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

# Alternative: Build and push with tags
push-release-image:
  stage: push
  image: docker:24-dind
  services:
    - docker:24-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build --tag $IMAGE_NAME:$CI_COMMIT_TAG .
    - docker push $IMAGE_NAME:$CI_COMMIT_TAG
  rules:
    - if: $CI_COMMIT_TAG
```

### Pattern 2: Docker Build with Kaniko (Rootless)

**Use case:** Building Docker images without Docker-in-Docker (more secure).

```yaml
stages:
  - build

variables:
  IMAGE_NAME: $CI_REGISTRY_IMAGE

docker-build-kaniko:
  stage: build
  image:
    name: gcr.io/kaniko-project/executor:v1.21.0-debug
    entrypoint: [""]
  script:
    - mkdir -p /kaniko/.docker
    - echo "{\"auths\":{\"${CI_REGISTRY}\":{\"auth\":\"$(printf "%s:%s" "${CI_REGISTRY_USER}" "${CI_REGISTRY_PASSWORD}" | base64 | tr -d '\n')\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor
        --context "${CI_PROJECT_DIR}"
        --dockerfile "${CI_PROJECT_DIR}/Dockerfile"
        --destination "${IMAGE_NAME}:${CI_COMMIT_SHORT_SHA}"
        --destination "${IMAGE_NAME}:latest"
        --cache=true
        --cache-ttl=24h
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### Pattern 3: Multi-Platform Docker Build

**Use case:** Building Docker images for multiple architectures.

```yaml
stages:
  - build

variables:
  DOCKER_DRIVER: overlay2

build-multiarch:
  stage: build
  image: docker:24-dind
  services:
    - docker:24-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
    - docker buildx create --use
  script:
    - docker buildx build
        --platform linux/amd64,linux/arm64
        --tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
        --tag $CI_REGISTRY_IMAGE:latest
        --push
        .
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

---

## Kubernetes Deployment Patterns

### Pattern 1: kubectl Deployment

**Use case:** Deploying to Kubernetes using kubectl.

```yaml
stages:
  - build
  - deploy

variables:
  KUBE_NAMESPACE: production
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

deploy-k8s:
  stage: deploy
  image: bitnami/kubectl:1.29
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
    - kubectl config set-context --current --namespace=$KUBE_NAMESPACE
  script:
    - kubectl set image deployment/myapp myapp=$CI_REGISTRY_IMAGE:$IMAGE_TAG
    - kubectl rollout status deployment/myapp --timeout=5m
  environment:
    name: production
    url: https://example.com
    kubernetes:
      namespace: $KUBE_NAMESPACE
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  when: manual
  resource_group: k8s-production
```

### Pattern 2: Helm Deployment

**Use case:** Deploying to Kubernetes using Helm charts.

```yaml
stages:
  - build
  - deploy

variables:
  HELM_CHART_PATH: ./helm/mychart
  RELEASE_NAME: myapp

deploy-helm-staging:
  stage: deploy
  image: alpine/helm:3.14.0
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    - helm upgrade --install $RELEASE_NAME $HELM_CHART_PATH
        --namespace staging
        --create-namespace
        --set image.tag=$CI_COMMIT_SHORT_SHA
        --set environment=staging
        --wait
        --timeout 5m
  environment:
    name: staging
    url: https://staging.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"

deploy-helm-production:
  stage: deploy
  image: alpine/helm:3.14.0
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    - helm upgrade --install $RELEASE_NAME $HELM_CHART_PATH
        --namespace production
        --create-namespace
        --set image.tag=$CI_COMMIT_TAG
        --set environment=production
        --wait
        --timeout 10m
  environment:
    name: production
    url: https://example.com
  rules:
    - if: $CI_COMMIT_TAG
  when: manual
  resource_group: k8s-production
```

### Pattern 3: Kustomize Deployment

**Use case:** Deploying to Kubernetes using Kustomize.

```yaml
stages:
  - deploy

deploy-kustomize:
  stage: deploy
  image:
    name: registry.k8s.io/kubectl:v1.29.1
    entrypoint: [""]
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    - cd k8s/overlays/$ENVIRONMENT
    - kustomize edit set image myapp=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
    - kustomize build . | kubectl apply -f -
    - kubectl rollout status deployment/myapp -n $ENVIRONMENT
  environment:
    name: $ENVIRONMENT
    kubernetes:
      namespace: $ENVIRONMENT
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      variables:
        ENVIRONMENT: production
  when: manual
```

---

## Testing Patterns

### Pattern 1: Comprehensive Testing Pipeline

**Use case:** Multiple types of tests (unit, integration, e2e).

```yaml
stages:
  - test
  - integration

variables:
  NODE_VERSION: "20"

default:
  image: node:${NODE_VERSION}-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
    policy: pull

test-unit:
  stage: test
  needs: []
  script:
    - npm ci
    - npm run test:unit
  coverage: '/Coverage: \d+\.\d+%/'
  artifacts:
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

test-lint:
  stage: test
  needs: []
  script:
    - npm ci
    - npm run lint
  allow_failure: true

test-types:
  stage: test
  needs: []
  image: node:${NODE_VERSION}-alpine
  script:
    - npm ci
    - npm run type-check

test-integration:
  stage: integration
  needs: [test-unit]
  services:
    - postgres:15-alpine
    - redis:7-alpine
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: testuser
    POSTGRES_PASSWORD: testpass
    DATABASE_URL: postgres://testuser:testpass@postgres:5432/testdb
    REDIS_URL: redis://redis:6379
  script:
    - npm ci
    - npm run test:integration
  retry:
    max: 2
    when:
      - runner_system_failure
      - api_failure

test-e2e:
  stage: integration
  needs: [test-unit]
  image: cypress/browsers:node-20.11.0-chrome-121.0.6167.85-1-ff-123.0-edge-121.0.2277.83-1
  script:
    - npm ci
    - npm run start:test &
    - npx wait-on http://localhost:3000
    - npm run test:e2e
  artifacts:
    when: always
    paths:
      - cypress/videos/
      - cypress/screenshots/
    expire_in: 1 week
```

### Pattern 2: Matrix Testing (Multiple Versions)

**Use case:** Testing across multiple language/platform versions.

```yaml
stages:
  - test

test-matrix:
  stage: test
  parallel:
    matrix:
      - NODE_VERSION: ['18', '20', '22']
        OS: ['alpine', 'bookworm-slim']
  image: node:${NODE_VERSION}-${OS}
  script:
    - node --version
    - npm --version
    - npm ci
    - npm test
```

### Pattern 3: Security Scanning

**Use case:** SAST, dependency scanning, container scanning.

```yaml
include:
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Dependency-Scanning.gitlab-ci.yml
  - template: Security/Container-Scanning.gitlab-ci.yml

stages:
  - test
  - security

# Customize SAST
semgrep-sast:
  variables:
    SAST_EXCLUDED_PATHS: "spec, test, tests, tmp"

# Customize dependency scanning
gemnasium-dependency_scanning:
  variables:
    DS_EXCLUDED_PATHS: "node_modules, vendor"

# Container scanning after build
container_scanning:
  variables:
    CS_IMAGE: $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  needs: [build-docker-image]
```

---

## Deployment Patterns

### Pattern 1: Multi-Environment Deployment

**Use case:** Deploy to multiple environments (dev, staging, production).

```yaml
stages:
  - build
  - deploy

variables:
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

.deploy-template:
  image: alpine:3.19
  before_script:
    - apk add --no-cache curl
  script:
    - curl -X POST $DEPLOY_WEBHOOK_URL
        -H "Authorization: Bearer $DEPLOY_TOKEN"
        -d "{\"environment\":\"${ENVIRONMENT}\",\"version\":\"${IMAGE_TAG}\"}"
  resource_group: ${ENVIRONMENT}

deploy-dev:
  extends: .deploy-template
  stage: deploy
  variables:
    ENVIRONMENT: development
  environment:
    name: development
    url: https://dev.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"

deploy-staging:
  extends: .deploy-template
  stage: deploy
  variables:
    ENVIRONMENT: staging
  environment:
    name: staging
    url: https://staging.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  when: manual

deploy-production:
  extends: .deploy-template
  stage: deploy
  variables:
    ENVIRONMENT: production
  environment:
    name: production
    url: https://example.com
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
  when: manual
  needs: [deploy-staging]
```

### Pattern 2: Blue-Green Deployment

**Use case:** Zero-downtime deployments with blue-green strategy.

```yaml
stages:
  - deploy
  - verify
  - switch

deploy-green:
  stage: deploy
  script:
    - kubectl apply -f k8s/deployment-green.yaml
    - kubectl rollout status deployment/myapp-green -n production
  environment:
    name: production-green
    url: https://green.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  when: manual

verify-green:
  stage: verify
  needs: [deploy-green]
  script:
    - curl -f https://green.example.com/health || exit 1
    - npm run test:smoke -- --baseUrl=https://green.example.com
  retry:
    max: 3
    when: always

switch-traffic:
  stage: switch
  needs: [verify-green]
  script:
    - kubectl patch service myapp -n production -p '{"spec":{"selector":{"version":"green"}}}'
    - echo "Traffic switched to green deployment"
  environment:
    name: production
    url: https://example.com
  when: manual
```

### Pattern 3: Canary Deployment

**Use case:** Gradual rollout with traffic splitting.

```yaml
stages:
  - deploy
  - canary

deploy-canary:
  stage: deploy
  script:
    - kubectl apply -f k8s/deployment-canary.yaml
    - kubectl set image deployment/myapp-canary myapp=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  environment:
    name: production-canary
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  when: manual

# Increase canary traffic gradually
canary-10-percent:
  stage: canary
  script:
    - kubectl patch virtualservice myapp -n production --type merge -p '{"spec":{"http":[{"route":[{"destination":{"host":"myapp-stable"},"weight":90},{"destination":{"host":"myapp-canary"},"weight":10}]}]}}'
  needs: [deploy-canary]
  when: manual

canary-50-percent:
  stage: canary
  script:
    - kubectl patch virtualservice myapp -n production --type merge -p '{"spec":{"http":[{"route":[{"destination":{"host":"myapp-stable"},"weight":50},{"destination":{"host":"myapp-canary"},"weight":50}]}]}}'
  needs: [canary-10-percent]
  when: manual

canary-promote:
  stage: canary
  script:
    - kubectl patch virtualservice myapp -n production --type merge -p '{"spec":{"http":[{"route":[{"destination":{"host":"myapp-canary"},"weight":100}]}]}}'
    - kubectl set image deployment/myapp-stable myapp=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  needs: [canary-50-percent]
  when: manual
```

---

## Multi-Project Pipeline Patterns

### Pattern 1: Trigger Downstream Projects

**Use case:** Orchestrate multiple project pipelines.

```yaml
stages:
  - build
  - trigger

build-library:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - dist/

trigger-dependent-projects:
  stage: trigger
  parallel:
    matrix:
      - PROJECT: ['group/app1', 'group/app2', 'group/app3']
  trigger:
    project: $PROJECT
    branch: main
    strategy: depend
  needs: [build-library]
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

### Pattern 2: Multi-Project Pipeline with Variables

**Use case:** Pass variables to downstream pipelines.

```yaml
trigger-downstream:
  stage: deploy
  trigger:
    project: group/deployment-project
    branch: main
    strategy: depend
  variables:
    SERVICE_NAME: my-service
    SERVICE_VERSION: $CI_COMMIT_SHORT_SHA
    ENVIRONMENT: production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  when: manual
```

---

## Parent-Child Pipeline Patterns

### Pattern 1: Dynamic Child Pipeline

**Use case:** Generate child pipeline configuration dynamically.

```yaml
stages:
  - generate
  - deploy

generate-child-pipeline:
  stage: generate
  script:
    - python scripts/generate-pipeline.py > generated-pipeline.yml
  artifacts:
    paths:
      - generated-pipeline.yml

trigger-child-pipeline:
  stage: deploy
  trigger:
    include:
      - artifact: generated-pipeline.yml
        job: generate-child-pipeline
    strategy: depend
  needs: [generate-child-pipeline]
```

### Pattern 2: Monorepo with Multiple Child Pipelines

**Use case:** Each component has its own pipeline configuration.

```yaml
# Parent .gitlab-ci.yml
stages:
  - trigger

trigger-frontend:
  stage: trigger
  trigger:
    include: frontend/.gitlab-ci.yml
    strategy: depend
  rules:
    - changes:
        - frontend/**/*

trigger-backend:
  stage: trigger
  trigger:
    include: backend/.gitlab-ci.yml
    strategy: depend
  rules:
    - changes:
        - backend/**/*

trigger-infrastructure:
  stage: trigger
  trigger:
    include: infrastructure/.gitlab-ci.yml
    strategy: depend
  rules:
    - changes:
        - infrastructure/**/*
```

---

## Monorepo Patterns

### Pattern 1: Conditional Jobs Based on Changes

**Use case:** Only run jobs for changed components.

```yaml
stages:
  - build
  - test
  - deploy

build-frontend:
  stage: build
  script:
    - cd frontend
    - npm ci
    - npm run build
  rules:
    - changes:
        - frontend/**/*

build-backend:
  stage: build
  script:
    - cd backend
    - go build
  rules:
    - changes:
        - backend/**/*

test-frontend:
  stage: test
  needs: [build-frontend]
  script:
    - cd frontend
    - npm test
  rules:
    - changes:
        - frontend/**/*

test-backend:
  stage: test
  needs: [build-backend]
  script:
    - cd backend
    - go test ./...
  rules:
    - changes:
        - backend/**/*
```

### Pattern 2: Monorepo with Parallel Child Pipelines

**Use case:** Run multiple child pipelines in parallel for different components.

```yaml
stages:
  - trigger

.trigger-template:
  stage: trigger
  trigger:
    strategy: depend

trigger-service-a:
  extends: .trigger-template
  trigger:
    include: services/service-a/.gitlab-ci.yml
  rules:
    - changes:
        - services/service-a/**/*

trigger-service-b:
  extends: .trigger-template
  trigger:
    include: services/service-b/.gitlab-ci.yml
  rules:
    - changes:
        - services/service-b/**/*

trigger-service-c:
  extends: .trigger-template
  trigger:
    include: services/service-c/.gitlab-ci.yml
  rules:
    - changes:
        - services/service-c/**/*
```

---

## Template and Reusability Patterns

### Pattern 1: Global Template Library

**Use case:** Reusable templates across multiple projects.

```yaml
# templates/build-templates.yml
.node-build-template:
  image: node:20-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  before_script:
    - npm ci
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour

.python-build-template:
  image: python:3.12-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - .venv/
  before_script:
    - python -m venv .venv
    - source .venv/bin/activate
    - pip install -r requirements.txt
  script:
    - python setup.py build
```

```yaml
# Project .gitlab-ci.yml
include:
  - project: 'group/ci-templates'
    file: 'templates/build-templates.yml'

stages:
  - build

build-app:
  extends: .node-build-template
  stage: build
```

### Pattern 2: Local Template with Extends

**Use case:** DRY configuration within a single project.

```yaml
# Hidden template jobs
.deployment-base:
  image: alpine:3.19
  before_script:
    - apk add --no-cache curl
  script:
    - ./scripts/deploy.sh $ENVIRONMENT
  resource_group: ${ENVIRONMENT}
  retry:
    max: 2
    when:
      - runner_system_failure

# Actual deployment jobs
deploy-staging:
  extends: .deployment-base
  stage: deploy
  variables:
    ENVIRONMENT: staging
  environment:
    name: staging
    url: https://staging.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

deploy-production:
  extends: .deployment-base
  stage: deploy
  variables:
    ENVIRONMENT: production
  environment:
    name: production
    url: https://example.com
  rules:
    - if: $CI_COMMIT_TAG
  when: manual
```

---

## Summary

These patterns provide a solid foundation for common GitLab CI/CD scenarios. When using these patterns:

1. **Customize** them for your specific needs
2. **Validate** using gitlab-ci-validator skill
3. **Follow** best practices from references/best-practices.md
4. **Test** locally when possible
5. **Document** any modifications

**Remember:** These are starting points. Always adapt them to your project's specific requirements, security policies, and infrastructure.