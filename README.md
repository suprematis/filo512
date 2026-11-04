# Filo512: Automated Bare-Metal AVX-512 vs. AVX2 Benchmark Suite

**Filo512** is a reproducible, hardware-level benchmarking harness designed to measure true architectural uplift between **AVX-512** (such as AMD Zen 4 double-pumped 256-bit vs. Zen 5 native 512-bit execution paths) and **AVX2** fallbacks on Linux bare-metal servers.

Rather than relying purely on user-space instruction flags, Filo512 executes a **two-pass kernel state machine**:
1. **Pass 1 (avx512_on):** Audits CPU topology, locks the `performance` frequency governor, and executes the benchmark suite with full hardware AVX-512 enabled.
2. **Kernel Masking (clearcpuid=avx512f):** Injects an isolated GRUB drop-in (`/etc/default/grub.d/99-filo512.cfg`) to disable AVX-512 at the OS/CPU capability mask level and automatically reboots the bare-metal server.
3. **Pass 2 (avx512_off):** Re-runs the suite so applications with runtime dynamic dispatch (like ClickHouse) are forced onto their AVX2 execution paths on the exact same physical silicon, then restores native GRUB settings and generates `results/SUMMARY.md`.

---

## Workloads Included

* **C++ SIMD Microbenchmark (workloads/microbench/):** Hand-unrolled FP32 dot-product kernels compiled with GCC 14 comparing `-mavx2 -mfma` (`ymm` 256-bit registers) vs. `-mavx512f -mfma` (`zmm` 512-bit registers), instrumented with `perf stat` cycle, instruction, and IPC counters.
* **SVT-AV1 4K Video Encoding (workloads/svt_av1/):** Generates an uncompressed 3840x2160 Y4M stream and benchmarks `SvtAv1EncApp` with `--asm avx2` vs. `--asm avx512`.
* **ClickHouse Vector Search & Batch Filtering (workloads/clickhouse/):** Populates an in-memory table of 256-dimension FP32 embeddings and measures `cosineDistance` + `LIKE` string filtering throughput across Pass 1 (native AVX-512 dynamic dispatch) and Pass 2 (kernel-masked AVX2 fallback).

---

## Repository Architecture

    filo512/
    ├── scripts/
    │   ├── 00_preflight_env.sh         # Installs toolchains, locks governor, records CPUID/kernel flags
    │   ├── 01_toggle_kernel_avx512.sh  # Manages /etc/default/grub.d/99-filo512.cfg (clearcpuid=avx512f)
    │   ├── run_all.sh                  # Runs preflight + workloads for a single pass (avx512_on / avx512_off)
    │   ├── auto_pipeline.sh            # Provider-agnostic two-pass systemd state machine (zero embedded secrets)
    │   ├── install_standalone.sh       # Registers filo512-runner.service on any standalone Ubuntu/Debian server
    │   └── parse_results.py            # Parses logs and generates results/SUMMARY.md
    ├── workloads/
    │   ├── microbench/                 # C++ AVX2 vs. AVX-512 dot-product harness
    │   ├── svt_av1/                    # 4K Y4M SVT-AV1 encoder benchmark
    │   └── clickhouse/                 # ClickHouse local vector cosineDistance benchmark
    └── terraform/
        └── latitude/                   # Ephemeral cloud-init & Terraform IaC for Latitude.sh bare-metal nodes

---

## Mode 1: Run on Any Independent Bare-Metal Server (Zero Cloud Credentials)

Filo512 contains **zero hardcoded credentials** or cloud dependencies. You can run it on any dedicated Ubuntu 24.04 / Debian bare-metal server in your lab or data center.

### Option A: Automated Two-Pass Run (With Automatic Reboot)

Clones the repo, registers a temporary `systemd` oneshot service (`filo512-runner.service`), executes Pass 1, masks AVX-512 in GRUB, reboots into Pass 2, restores GRUB, disables the service, and writes the final report to `/opt/filo512/results/SUMMARY.md`.

    git clone https://github.com/suprematis/filo512.git /opt/filo512
    cd /opt/filo512

    # Run full production benchmark iterations locally (no GitHub push, no cloud API calls)
    sudo DRY_RUN=false ./scripts/install_standalone.sh

    # Monitor live progress across both passes:
    sudo tail -f /var/log/filo512-autorun.log

*(To test the reboot pipeline quickly with reduced iterations, pass `sudo DRY_RUN=true ./scripts/install_standalone.sh`).*

### Option B: Manual Single-Pass Run (No Reboot / No GRUB Modification)

If you want to benchmark a workstation or shared server without modifying GRUB or rebooting:

    git clone https://github.com/suprematis/filo512.git
    cd filo512

    # Run Pass 1 (Native AVX-512)
    DRY_RUN=false ./scripts/run_all.sh avx512_on

---

## Mode 2: Standalone Server with Automated GitHub Branch Push

If you are running on an independent bare-metal server and want the machine to automatically push its finished `results/<CPU_MODEL>-<TIMESTAMP>` branch back to your fork upon completing Pass 2, pass ephemeral environment variables to `install_standalone.sh`:

    cd /opt/filo512
    sudo DRY_RUN=false \
         PUSH_RESULTS=true \
         GITHUB_USER="suprematis" \
         GITHUB_REPO="filo512" \
         GITHUB_TOKEN="github_pat_..." \
         ./scripts/install_standalone.sh

*Security Note:* Runtime variables are stored in `/etc/filo512.env` with `0600` (`root`-only) permissions, `set +x` prevents token echoing in logs, and `git push` uses an in-memory URL so credentials are never written to `.git/config`.

---

## Mode 3: Ephemeral Bare-Metal Automation via Terraform (Latitude.sh)

For cloud bare-metal benchmarking on Latitude.sh, the Terraform configuration in `terraform/latitude/` provisions an instance, injects `/etc/filo512.env` via `#cloud-config`, runs both passes, pushes the results branch to GitHub, and optionally self-destructs the server via the Latitude API the second the push completes.

### 1. Export Credentials Locally (Never Committed to Git)

    export LATITUDESH_AUTH_TOKEN="your_latitude_api_token"
    export TF_VAR_latitude_api_key="$LATITUDESH_AUTH_TOKEN"
    export TF_VAR_github_user="suprematis"
    export TF_VAR_github_token="github_pat_your_fine_grained_token"

### 2. Initialize & Run Smoke Test (m4-metal-small / Zen 4 in SJC2)

    cd terraform/latitude
    terraform init
    terraform apply -auto-approve \
      -var="plan=m4-metal-small" \
      -var="site=SJC2" \
      -var="dry_run=true" \
      -var="auto_destroy=false"

### 3. Launch Full Production Benchmark (f4-metal-large / Zen 5 EPYC 9275F in AMS)

With `dry_run=false` and `auto_destroy=true`, the node runs the full iteration suite across both passes, pushes `results/AMD_EPYC_9275F_...` to GitHub, and immediately terminates itself via the Latitude API to minimize hourly billing:

    cd terraform/latitude
    terraform apply -auto-approve \
      -var="plan=f4-metal-large" \
      -var="site=AMS" \
      -var="dry_run=false" \
      -var="auto_destroy=true"

### 4. Fetch Results & Clean Up Terraform State

    git fetch --all
    LATEST_BRANCH=$(git branch -r | grep -o 'origin/results/[^ ]*' | tail -n1)
    git show "${LATEST_BRANCH}:results/SUMMARY.md"

    # Reconcile and clean up remaining Terraform resources
    terraform destroy -auto-approve
