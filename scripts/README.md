# Filo512 Standalone Bare-Metal Runner

Run the full two-pass AVX-512 vs. AVX2 benchmark suite interactively over SSH on any stock Ubuntu 22.04 or 24.04 server—without Terraform, cloud-init, or GitHub credentials.

## Quick Start (Zero-Dependency `curl` Bootstrap)

On a fresh Ubuntu install (even minimal ISOs without `git` pre-installed), run this single command for **Pass 1** (`avx512_on`):

```bash
curl -fsSL https://raw.githubusercontent.com/suprematis/filo512/main/scripts/bootstrap.sh | bash
```

### Fast Dry-Run Validation (~90 seconds)

To verify package installation, `perf` permissions, GRUB `clearcpuid` masking, and reboot recovery before running full production iterations:

```bash
curl -fsSL https://raw.githubusercontent.com/suprematis/filo512/main/scripts/bootstrap.sh | DRY_RUN=true bash
```

---

## Two-Pass Execution Flow

1. **Pass 1 (Native AVX-512 Enabled):**
   - Installs required compilers (`g++-14`), build tools (`cmake`, `ninja-build`, `nasm`), `linux-tools`, and `gawk`.
   - Sets `kernel.perf_event_paranoid=-1` and locks `scaling_governor` to `performance` (when exposed by BIOS).
   - Runs C++ L2-resident SIMD dot-product, SVT-AV1 v2.3.0 4K encode, and ClickHouse vector search + filter.
   - Writes `/etc/default/grub.d/99-filo512.cfg` (`clearcpuid=...`) to mask AVX-512 at the kernel level and prompts to reboot.

2. **Reboot & Reconnect:**
   - Confirm `y` at the prompt (or run `sudo reboot`) and wait ~2–3 minutes for bare-metal UEFI POST.

3. **Pass 2 (Kernel-Masked AVX2 Fallback):**
   - SSH back into the server and re-run the **exact same command**:
     ```bash
     curl -fsSL https://raw.githubusercontent.com/suprematis/filo512/main/scripts/bootstrap.sh | bash
     ```
     *(Or if running directly from the cloned repo: `cd ~/filo512 && ./scripts/run_standalone.sh` — include `DRY_RUN=true` if Pass 1 used dry-run mode).*
   - Verifies AVX-512 flags are masked (`NONE`), executes Pass 2, generates `results/SUMMARY.md`, **automatically restores GRUB to native AVX-512**, and bundles all logs into `~/filo512/filo512_<CPU>_<TIMESTAMP>.tar.gz`.

---

## Resetting State for a Fresh Run

State markers are stored in `~/filo512/.state/`. To wipe previous state and re-run from Pass 1:

```bash
rm -rf ~/filo512/.state ~/filo512/results/*
```

If a run is ever aborted mid-flight after Pass 1 modified GRUB and you want to manually restore native AVX-512 before rebooting:

```bash
cd ~/filo512 && ./scripts/01_toggle_kernel_avx512.sh enable
```
