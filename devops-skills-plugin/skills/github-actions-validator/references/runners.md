# GitHub-Hosted Runners Reference (2025)

This reference covers all GitHub-hosted runner types, including recent additions and deprecations.

## Standard Runner Labels

### Ubuntu

```yaml
runs-on: ubuntu-latest      # Ubuntu 24.04 (default)
runs-on: ubuntu-24.04       # Ubuntu 24.04
runs-on: ubuntu-22.04       # Ubuntu 22.04
runs-on: ubuntu-20.04       # Ubuntu 20.04
```

### Windows

```yaml
runs-on: windows-latest     # Windows Server 2022 (default)
runs-on: windows-2025       # Windows Server 2025 (NEW)
runs-on: windows-2022       # Windows Server 2022
runs-on: windows-2019       # Windows Server 2019
```

### macOS

```yaml
runs-on: macos-latest       # macOS 15 (as of Aug 2025)
runs-on: macos-15           # macOS 15 Sequoia (Apple Silicon)
runs-on: macos-14           # macOS 14 Sonoma (Apple Silicon)
runs-on: macos-26           # macOS 26 (PREVIEW)
```

---

## macOS Runner Updates and Deprecations

### Current Status

| Label | Status | Architecture | Notes |
|-------|--------|--------------|-------|
| `macos-latest` | **Active** | ARM64 (Apple Silicon) | Points to macOS 15 |
| `macos-15` | **Active** | ARM64 (Apple Silicon) | M1/M2/M3 |
| `macos-14` | **Active** | ARM64 (Apple Silicon) | M1/M2 |
| `macos-26` | **Preview** | ARM64 (Apple Silicon) | Beta |
| `macos-13` | **RETIRED** | Intel x86_64 | Retired November 14, 2025 |
| `macos-12` | **RETIRED** | Intel x86_64 | Retired |

### Intel-Specific Labels (Long-term Deprecated)

```yaml
runs-on: macos-15-intel     # Intel x86_64 (NEW but deprecated long-term)
runs-on: macos-14-large     # Intel x86_64
runs-on: macos-15-large     # Intel x86_64
```

**Important:** Apple Silicon (ARM64) will be required after Fall 2027. Plan migration now.

### Migration Example

```yaml
jobs:
  build:
    # BAD - macos-13 retired Nov 14, 2025 (WILL FAIL)
    # runs-on: macos-13

    # GOOD - Use macos-15 or macos-latest
    runs-on: macos-15

    steps:
      - uses: actions/checkout@v6
      - run: ./build.sh
```

---

## ARM64 Runners

### Availability
- **Generally available** as of August 2025
- **Free** for public repositories
- **Private repositories** require GitHub Enterprise Cloud plan

### Labels

```yaml
runs-on: ubuntu-latest-arm64    # Free for public repos
runs-on: ubuntu-24.04-arm64
runs-on: windows-latest-arm64   # ARM Windows
```

### Example

```yaml
jobs:
  build:
    runs-on: ubuntu-latest-arm64  # Free for public repos
    steps:
      - uses: actions/checkout@v6
      - name: Build on ARM64
        run: |
          uname -m  # Should output: aarch64
          ./build.sh
```

### Specifications
- 4 vCPU ARM64 processors
- Available for Linux and Windows
- Native ARM execution (no virtualization needed)
- Ideal for multi-architecture builds

### Common Validation Issues
- Using ARM64 runners in private repos without Enterprise Cloud
- Assuming all community actions work on ARM64
- Not testing ARM-specific compilation issues

---

## GPU Runners

### Availability
- **Generally available** for Windows and Linux
- Requires **Team** or **Enterprise Cloud** plan

### Labels

```yaml
runs-on: gpu-t4-4-core      # NVIDIA Tesla T4
```

### Specifications
- **GPU:** NVIDIA Tesla T4 with 16GB VRAM
- **CPU:** 4 vCPUs
- **RAM:** 28GB
- **Pricing:** $0.07/minute

### Example

```yaml
jobs:
  ml-training:
    runs-on: gpu-t4-4-core
    steps:
      - uses: actions/checkout@v6

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install ML dependencies
        run: |
          pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
          pip install -r requirements.txt

      - name: Train model
        run: python train.py --use-gpu

      - name: Run inference
        run: python inference.py
```

### Use Cases
- ML model training
- GPU-accelerated testing
- CUDA development
- Image/video processing

### Common Validation Issues
- Missing CUDA setup
- Incorrect GPU driver versions
- Not utilizing GPU in workloads (CPU fallback)
- Missing GPU-specific dependencies

---

## M2 Pro macOS Runners (Larger Runners)

### Availability
- **Generally available** with M2 Pro powered runners

### Labels

```yaml
runs-on: macos-latest-xlarge  # macOS 15, M2 Pro
runs-on: macos-15-xlarge      # macOS 15, M2 Pro
runs-on: macos-14-xlarge      # macOS 14, M2 Pro
```

### Specifications
- **CPU:** 5-core (vs 3-core standard)
- **GPU:** 8-core with hardware acceleration (enabled by default)
- **RAM:** 14GB
- **Storage:** 14GB
- **Performance:** Up to 15% faster than M1 runners
- **Pricing:** $0.16/minute

### Example

```yaml
jobs:
  ios-build:
    runs-on: macos-15-xlarge  # M2 Pro with GPU acceleration
    steps:
      - uses: actions/checkout@v6

      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable

      - name: Build iOS app
        run: |
          xcodebuild -workspace App.xcworkspace \
            -scheme Production \
            -configuration Release \
            -archivePath build/App.xcarchive \
            archive

      - name: Run GPU-accelerated tests
        run: |
          # GPU acceleration automatically available
          xcodebuild test -scheme AppTests
```

### Benefits
- GPU hardware acceleration for Metal-based workloads
- Improved build times for iOS/macOS apps
- Better performance for Xcode builds
- Native Apple Silicon performance

---

## Runner Selection Best Practices

### Decision Criteria

1. **Architecture compatibility:** ARM64 vs Intel x86_64
2. **Cost optimization:** Standard vs larger runners
3. **GPU requirements:** ML/AI workloads need GPU runners
4. **Operating system:** Latest versions recommended
5. **Deprecation timelines:** Avoid retired runners
6. **Public vs private repos:** ARM64 free only for public repos

### Validation Checklist

```yaml
# Check these in your workflows:
- [ ] Using latest runner versions (macos-15, windows-2025, ubuntu-latest)
- [ ] Not using deprecated runners (macos-13)
- [ ] Architecture-appropriate runners (ARM64 vs Intel)
- [ ] GPU runners for ML workloads
- [ ] Cost-effective runner selection
- [ ] ARM64 compatibility tested (if using ARM64 runners)
```

### Cost Comparison

| Runner Type | Pricing | Best For |
|-------------|---------|----------|
| Standard (Linux/Windows) | Included | Most workloads |
| Standard (macOS) | Included | iOS/macOS builds |
| ARM64 (public repos) | **Free** | Multi-arch builds |
| ARM64 (private repos) | Enterprise | ARM-native builds |
| GPU (T4) | $0.07/min | ML/AI workloads |
| M2 Pro (xlarge) | $0.16/min | Heavy iOS builds |

---

## Multi-Architecture Builds

### Example: Building for Multiple Architectures

```yaml
jobs:
  build:
    strategy:
      matrix:
        include:
          - runner: ubuntu-latest
            arch: x64
          - runner: ubuntu-latest-arm64
            arch: arm64

    runs-on: ${{ matrix.runner }}
    steps:
      - uses: actions/checkout@v6

      - name: Build
        run: |
          echo "Building for ${{ matrix.arch }}"
          ./build.sh --arch ${{ matrix.arch }}

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ matrix.arch }}
          path: dist/
```

---

## Self-Hosted Runner Configuration

When using self-hosted runners, configure actionlint to recognize custom labels:

```yaml
# .github/actionlint.yaml
self-hosted-runner:
  labels:
    - my-custom-runner
    - gpu-runner
    - arm-runner
    - on-premises
```

This prevents actionlint from reporting unknown runner label errors.