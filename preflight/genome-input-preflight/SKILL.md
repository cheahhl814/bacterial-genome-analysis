---
name: genome-input-preflight
description: Validate bacterial genome analysis inputs (cleaned reads) and write a preflight.md audit trail + params.json platform contract. Computes evidence (read stats, coverage, contamination, disk, resource budget) and emits a GO / GO-WITH-WARNINGS / NO-GO verdict. Always run after read-qc-trimming and before any assembly sub-skill. Has 7 explicit ask-user stop points (SP1–SP7) that fire only when evidence is ambiguous. Triggers: "preflight bacterial genome", "what params for bacterial assembly", "bacterial genome preflight", "validate my cleaned reads", "should I assemble these reads".
version: 5.0.2
updated: "2026-08-14"
triggers:
  - "preflight bacterial genome"
  - "what params for bacterial assembly"
  - "bacterial genome preflight"
  - "validate my cleaned reads"
  - "should I assemble these reads"
  - "set up bacterial genome run"
  - "bacterial genome params.json"
---

# Skill: genome-input-preflight

> **v5.0.1.** New sub-skill. Mirrors the `bettamt-preflight` pattern from [BettaMt-agents](https://github.com/cheahhl814/BettaMt-agents/blob/master/.agents/skills/bettamt-preflight/SKILL.md): gather inputs → compute evidence → write `params.json` (machine contract) + `preflight.md` (human audit). **Never** invokes the assembly sub-skills. The assembly sub-skills refuse to run without `preflight.md` ≥ `GO-WITH-WARNINGS`.

## Audience

This skill serves two purposes:
- **AI Agents**: Triggered by phrases like *"preflight bacterial genome"* or *"what params should I use"*. Must run all evidence collection steps, then write `params.json` + `preflight.md`.
- **Human Users**: Provides a transparent audit trail — every recommendation is cited back to a measured piece of evidence.

## When to Use This Skill

Use this skill if:
- You have **cleaned reads** (from `read-qc-trimming`) and want to know whether the dataset is ready for assembly.
- You need to choose between **short-read**, **long-read**, or **hybrid** assembly paths.
- You want a **machine-readable `params.json`** that the assembly sub-skills can read without re-deriving choices.
- You want a **human-readable `preflight.md`** that documents the audit trail (suitable for supplementary materials).

Do NOT use this skill if:
- You only have **raw reads** — run `read-qc-trimming` first. This skill assumes cleaned reads.
- You want to assemble immediately — this skill is the gate, not the assembly itself.
- You are working with eukaryotic, viral, or metagenomic data — different paradigms apply.

## 0. Inputs / Outputs contract

### Inputs (consumed)
| Path | Source | Required? |
| --- | --- | --- |
| `$RUN_DIR/cleaned_R1.fastq.gz` | `read-qc-trimming` | conditional (yes for Illumina / hybrid) |
| `$RUN_DIR/cleaned_R2.fastq.gz` | `read-qc-trimming` | conditional (yes for paired-end Illumina / hybrid) |
| `$RUN_DIR/cleaned_long.fastq.gz` | `read-qc-trimming` | conditional (yes for ONT / PacBio / hybrid) |

### Outputs (produced)
| Path | Owner | Format | Notes |
| --- | --- | --- | --- |
| `$RUN_DIR/params.json` | this skill | JSON | **Machine contract for the assembly sub-skills.** Schema below. |
| `$RUN_DIR/preflight.md` | this skill | Markdown | **Human audit trail.** Verdict summary + evidence + recommendations. |
| `$RUN_DIR/preflight_evidence.txt` | this skill | text | Raw evidence output (seqkit stats, kraken2 head, df, free, etc.) — kept for debugging. |

### Where to write
- Use `$RUN_DIR` (env var) or the current working directory if `$RUN_DIR` is unset.
- The next phase (`assembly/*`) reads `$RUN_DIR/params.json` to choose the assembler.
- The next phase also reads `$RUN_DIR/preflight.md` to verify the verdict gate.

### Verdict gate
The assembly sub-skills **refuse to run** unless `$RUN_DIR/preflight.md` overall verdict is `GO` or `GO-WITH-WARNINGS`. A `NO-GO` verdict stops the pipeline.

## 0.5 Ask-User Stop Points

This sub-skill has **7 stop points** (SP1–SP7). Each fires only when the evidence is ambiguous. The format is **Evidence + Recommend + Options**. If the evidence is unambiguous, the agent auto-picks the default and proceeds silently.

### SP1 — Platform ambiguous (no FASTQ tells us)

| Trigger | Evidence check | Action |
| --- | --- | --- |
| No `cleaned_R1.fastq.gz` AND no `cleaned_long.fastq.gz` AND no user-provided path | Unambiguous missing data | Hard-stop: "I don't see any cleaned reads at `$RUN_DIR/`. Please run `read-qc-trimming` first, or paste the path to your cleaned FASTQ files." |
| User provided a single FASTQ path | Cannot infer platform from filename alone | Ask: "I see one FASTQ at `<path>`. What platform produced it? (Illumina / ONT / PacBio HiFi / PacBio CLR)" |

**Auto-pick when**: cleaned reads exist and filenames are clear (`cleaned_R1.fastq.gz` + `cleaned_R2.fastq.gz` → Illumina; `cleaned_long.fastq.gz` → ONT/PacBio).

### SP2 — Short AND long reads present (path choice)

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `cleaned_R{1,2}.fastq.gz` AND `cleaned_long.fastq.gz` all present | Real ambiguity | Ask: "I see both short reads (`cleaned_R1/2.fastq.gz`) and long reads (`cleaned_long.fastq.gz`). Which assembly path do you want? (A) short-read-only, (B) long-read-only, (C) hybrid (Unicycler/Dragonflye)" |

**Auto-pick when**: only one platform's reads are present. Default: hybrid IF both have sufficient coverage (Illumina ≥ 50× AND long-read ≥ 30×).

### SP3 — Expected genome size missing

| Trigger | Evidence check | Action |
| --- | --- | --- |
| User did not provide `expected_genome_size_mb` | Coverage estimate is approximate | Ask: "I don't know the expected genome size. Pick one: (A) E. coli / typical Enterobacteriaceae (~4.6 Mbp), (B) Bacillus / Firmicutes (~4.2 Mbp), (C) Mycobacterium (~4.4 Mbp), (D) I'll provide it now" |

**Auto-pick when**: user provides a size in the initial brief. Default is 4.5 Mbp with a warning if the user doesn't know.

### SP4 — Organism / genus missing

| Trigger | Evidence check | Action |
| --- | --- | --- |
| User did not provide organism | Contamination screen has no "expected genus" anchor | Ask: "I don't know the expected organism. Pick one: (A) I'll provide it now, (B) infer from Kraken2 top hit (but then the contamination screen is less reliable), (C) skip organism validation entirely" |

**Auto-pick when**: user provides organism. Default: use Kraken2 top hit + warn "this is circular — if the assembly is contaminated, Kraken2 will misleadingly confirm the contaminant."

### SP5 — Tool missing or trap fires

| Trigger | Evidence check | Action |
| --- | --- | --- |
| Any required tool missing | `which` returns nothing | Ask: "Tool `<X>` is missing from the pixi env. Pick: (A) install it now (`pixi add <X>`), (B) skip this phase (no go), (C) abort" |
| `checkm-genome` triggers `pkg_resources` ModuleNotFoundError | Python 3.12+ setuptools trap | Ask: "CheckM is broken because of the Python 3.12 / setuptools ≥ 81 incompatibility. Pick: (A) I can fix it (run `pixi add 'setuptools<81'`), (B) use a different validator (BUSCO + QUAST only), (C) abort" |

**Auto-pick when**: all tools present and passing the trap check. No ask.

### SP6 — Contamination > 5% off-genus

| Trigger | Evidence check | Action |
| --- | --- | --- |
| Kraken2 top-pct for expected genus < 95% | Real contamination signal | Ask: "Kraken2 reports only `<X>%` of reads match the expected genus (target ≥ 95%). This is a real contamination signal. Pick: (A) continue with `GO-WITH-WARNINGS` — I'll document the contamination in `preflight.md`, (B) re-extract DNA / re-prep library (recommended), (C) abort" |

**Auto-pick when**: top-pct ≥ 95% (clean) OR 80–95% (still GO-WITH-WARNINGS — one ask is enough). For <50% (NO-GO), ask instead of auto-stopping — the user may want to override.

### SP7 — Disk space < 20 GB

| Trigger | Evidence check | Action |
| --- | --- | --- |
| Free space < 20 GB | NO-GO territory | Ask: "Only `<X> GB` free on `$RUN_DIR`. Bacterial assemblies need ≥ 50 GB. Pick: (A) free up disk by clearing intermediate files, (B) move `$RUN_DIR` to a larger disk, (C) abort" |

**Auto-pick when**: free space ≥ 50 GB. Warning auto-set for 20–50 GB (no ask).

### Operating rule

> **Auto-pick when the evidence is unambiguous; ask when the agent genuinely cannot decide.** When asking, present the evidence first, then the recommendation, then 2–4 concrete options. Do not ask "what do you want?" — ask "I see X, recommend Y, which one of A/B/C?"

## Description

This skill is the **input validation** phase of the bacterial genome pipeline. It computes six pieces of evidence (read statistics, platform detection, coverage estimate, contamination screen, disk space, resource budget) and emits a machine-readable `params.json` plus a human-readable `preflight.md` with a single overall verdict.

The design follows `bettamt-preflight` exactly: every recommendation is cited back to a measured piece of evidence. The agent does not invent parameters — it computes them.

## Prerequisites

- **Environment**: pixi env with at least `seqkit`, `minimap2`, `samtools`, `kraken2`, `numpy` (or `awk`) available. The sub-skill does NOT need the full assembly/polishing/QC toolchain.
- **Upstream Evidence**: Cleaned reads (`.fastq.gz`) produced by `read-qc-trimming`.
- **User-provided inputs** (gather once, at the top of the skill):
  - `expected_genome_size_mb` (optional, but strongly recommended) — used for coverage estimate.
  - `organism` (optional) — used for the contamination screen's expected-genus heuristic.

## Procedure

The procedure has **three phases**: (1) gather inputs, (2) compute evidence, (3) write outputs.

### 1. Gather inputs from the user

Ask once, in one question batch if possible:

| Input | Required? | Default if absent |
| --- | --- | --- |
| Path to cleaned read FASTQ file(s) | yes | detect from `$RUN_DIR/cleaned_*.fastq.gz` |
| Expected genome size (Mbp) | optional | infer from common bacterial sizes (E. coli ≈ 4.6 Mbp, B. subtilis ≈ 4.2 Mbp, M. tuberculosis ≈ 4.4 Mbp; warn if unknown) |
| Organism / genus | optional | `unknown` — used for contamination heuristic |
| Sequencer (ONT / PacBio / Illumina) | optional | infer from `seqkit stats` (mean read length) |

### 2. Compute evidence (always run; never skip)

Each numbered step produces a line in `preflight_evidence.txt` and a column in the `preflight.md` table.

#### 2a) Read statistics

```bash
pixi run --manifest-path "$RUN_DIR/../pixi.toml" seqkit stats \
    "$RUN_DIR/cleaned_R1.fastq.gz" \
    "$RUN_DIR/cleaned_R2.fastq.gz" \
    "$RUN_DIR/cleaned_long.fastq.gz" 2>/dev/null | tee -a "$RUN_DIR/preflight_evidence.txt"
```

Capture: `num_seqs`, `sum_len`, `avg_len`, `N50` (compute with `seqkit fx2tab -n -l` if not printed).

#### 2b) Platform auto-detection

```bash
MEAN_LEN=$(pixi run --manifest-path "$RUN_DIR/../pixi.toml" seqkit stats \
    "$RUN_DIR/cleaned_long.fastq.gz" 2>/dev/null | awk 'NR==2 {print $5}')
# If cleaned_long absent, use cleaned_R1 mean
```

| Evidence | Recommendation |
| --- | --- |
| User says "Illumina" / "NovaSeq" / "paired" | `illumina` |
| User says "ONT" / "PromethION" / "MinION" / "long-read" | `ont` |
| User says "PacBio HiFi" / "Revio" | `pacbio-hifi` |
| Mean read length > 1000 bp | `ont` |
| Two FASTQ files in `cleaned_R{1,2}` AND ONT FASTQ | `hybrid` |
| Two FASTQ files only, mean < 1000 bp | `illumina` |
| All else fails | **ask the user** |

Write `params.json` `$platform` field with the resolved value.

#### 2c) Coverage estimate

For Illumina (use first 100 k read pairs to keep it fast):

```bash
pixi run --manifest-path "$RUN_DIR/../pixi.toml" seqkit head -n 100000 "$RUN_DIR/cleaned_R1.fastq.gz" > /tmp/sample_R1.fq.gz
pixi run --manifest-path "$RUN_DIR/../pixi.toml" seqkit head -n 100000 "$RUN_DIR/cleaned_R2.fastq.gz" > /tmp/sample_R2.fq.gz
# If reference is available, map against it; otherwise use a rough formula
COV_RAW=$(pixi run --manifest-path "$RUN_DIR/../pixi.toml" minimap2 -ax sr -t 4 \
    <REFERENCE OR PLACEHOLDER> /tmp/sample_R1.fq.gz /tmp/sample_R2.fq.gz 2>/dev/null \
    | pixi run --manifest-path "$RUN_DIR/../pixi.toml" samtools view -bF 4 - \
    | pixi run --manifest-path "$RUN_DIR/../pixi.toml" samtools depth -a - \
    | awk '{s+=$3; n++} END {if (n>0) print s/n; else print "0"}')
```

If no reference is available, compute coverage from raw read depth:

```bash
# Total bases / expected genome size
TOTAL_BASES=$(pixi run --manifest-path "$RUN_DIR/../pixi.toml" seqkit stats "$RUN_DIR/cleaned_R1.fastq.gz" 2>/dev/null | awk 'NR==2 {print $5}')
GENOME_SIZE=$(echo "${EXPECTED_GENOME_SIZE_MB:-4.5} * 1000000" | bc -l)
COV_RAW=$(echo "scale=1; $TOTAL_BASES / $GENOME_SIZE" | bc -l)
```

For ONT, the same with `minimap2 -ax map-ont` instead of `-ax sr`.

| Coverage | Verdict | Notes |
| --- | --- | --- |
| Illumina: $50{-}200\times$ | `GO` | sweet spot for short-read assembly |
| Illumina: $30{-}50\times$ or $200{-}500\times$ | `GO-WITH-WARNINGS` | marginal / high — possible graph tangling |
| Illumina: $< 30\times$ | `NO-GO` | insufficient for MIMAG |
| ONT: $30{-}100\times$ | `GO` | sweet spot for long-read |
| ONT: $< 30\times$ or $> 200\times$ | `GO-WITH-WARNINGS` | marginal / excessive |
| HiFi: $15{-}50\times$ | `GO` | HiFi is higher accuracy per base |
| Any: $0\times$ | `NO-GO` | something is wrong — investigate |

#### 2d) Read-level contamination screen

```bash
pixi run --manifest-path "$RUN_DIR/../pixi.toml" kraken2 --db "${KRAKEN2_DB_PATH:-$SKILL_ROOT/assets/kraken2_db}" \
    --threads 4 \
    --quick \
    --output /tmp/kraken2_preflight.out \
    --report /tmp/kraken2_preflight_report.txt \
    --confidence 0.05 \
    "$RUN_DIR/cleaned_R1.fastq.gz" 2>/dev/null
```

Compute the top genus and its fraction:

```bash
TOP_GENUS=$(awk 'NR>1 {print $6"\t"$1}' /tmp/kraken2_preflight_report.txt | head -1)
TOP_PCT=$(awk 'NR==2 {print $1}' /tmp/kraken2_preflight_report.txt)
```

| Top genus % | Verdict | Action |
| --- | --- | --- |
| $> 95\%$ expected genus | `GO` | clean |
| $80{-}95\%$ expected genus | `GO-WITH-WARNINGS` | minor contamination |
| $50{-}80\%$ expected genus | `GO-WITH-WARNINGS` | moderate — consider re-prep |
| $< 50\%$ expected genus or any eukaryotic top hit | `NO-GO` | major contamination — re-extract DNA |

#### 2e) Disk space check

```bash
df -BG "$RUN_DIR" | awk 'NR==2 {print "Free space:", $4, "GB"}'
```

| Free space | Verdict |
| --- | --- |
| $> 50$ GB (typical isolate) | `GO` |
| $20{-}50$ GB | `GO-WITH-WARNINGS` |
| $< 20$ GB | `NO-GO` — recommend clearing `work/` or moving to a larger disk |

#### 2f) Tool availability check

```bash
for tool in seqkit minimap2 samtools kraken2 spades flye skesa megahit polypolish pypolca medaka quast checkm-genome busco bakta; do
    pixi run --manifest-path "$RUN_DIR/../pixi.toml" which "$tool" 2>/dev/null \
        | head -1 | awk -v t="$tool" '{print t" -> "$0}'
done
```

**Critical trap**: `checkm-genome` fails on Python 3.12+ with `setuptools ≥ 81` (the `pkg_resources` removal). Confirm:

```bash
pixi run --manifest-path "$RUN_DIR/../pixi.toml" python -c "import pkg_resources" 2>&1 \
    | grep -q "ModuleNotFoundError" && echo "TRAP: setuptools pin required" || echo "OK"
```

If the trap fires, the preflight verdict for that tool is `GO-WITH-WARNINGS` and the preflight.md must say `pixi add 'setuptools<81'` to fix it.

#### 2g) Resource assessment

```bash
NCPU=$(nproc)
RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
echo "Local machine: ncpu=$NCPU, ram=${RAM_GB}GB"
```

| Resource | Verdict | Notes |
| --- | --- | --- |
| $\geq 16$ cores, $\geq 64$ GB RAM | `GO` | ample for any assembly in this skill |
| $8{-}16$ cores, $32{-}64$ GB RAM | `GO-WITH-WARNINGS` | fine for short-read; tight for large long-read |
| $< 8$ cores or $< 16$ GB RAM | `GO-WITH-WARNINGS` | recommend SLURM or smaller subsamples |

### 3. Write outputs

#### 3a) `params.json` schema

```json
{
  "platform": "illumina|ont|pacbio-hifi|hybrid",
  "has_short": true,
  "has_long": true,
  "expected_genome_size_mb": 4.5,
  "organism": "Escherichia coli",
  "expected_genus": "Escherichia",
  "reads": {
    "r1": "$RUN_DIR/cleaned_R1.fastq.gz",
    "r2": "$RUN_DIR/cleaned_R2.fastq.gz",
    "long": "$RUN_DIR/cleaned_long.fastq.gz"
  },
  "coverage": {
    "estimated_x": 87.5,
    "platform": "illumina",
    "verdict": "GO"
  },
  "contamination": {
    "top_genus": "Escherichia",
    "top_pct": 97.3,
    "verdict": "GO"
  },
  "resources": {
    "ncpu": 16,
    "ram_gb": 64,
    "disk_gb_free": 320,
    "verdict": "GO"
  },
  "tools": {
    "seqkit": "OK",
    "minimap2": "OK",
    "kraken2": "OK",
    "checkm-genome": "GO-WITH-WARNINGS (pkg_resources trap; require setuptools<81)"
  },
  "recommendations": {
    "assembler": "spades",
    "assembler_rationale": "Illumina paired-end, 87.5x coverage, >95% expected-genus hits — SPAdes is the standard.",
    "polishing": "skip",
    "polishing_rationale": "Short-read-only assembly; polishing offers minimal benefit and can introduce over-correction.",
    "qc": "required"
  },
  "verdict": "GO",
  "warnings": [],
  "generated": "<ISO8601>"
}
```

Notes:
- `recommendations.assembler` is the **primary** recommendation. The assembly sub-skill uses it as the default; human override is allowed.
- `polishing` is `"skip"` for short-read-only, `"required"` for long-read or hybrid.
- `verdict` is one of `GO`, `GO-WITH-WARNINGS`, `NO-GO`.

#### 3b) `preflight.md` template

```markdown
# Bacterial genome preflight report

Run:        $RUN_DIR
Generated:  <ISO8601>
Pipeline:   bacterial-genome-analysis v5.0.1

## Overall verdict

**GO** ✅ *(or GO-WITH-WARNINGS ⚠️ / NO-GO ❌)*

<one-line summary, e.g. "Illumina dataset, 87.5x coverage, Escherichia, 64 GB RAM — ready for SPAdes short-read assembly.">

## Evidence

| Check | Verdict | Value | Threshold |
|---|---|---|---|
| Read stats (seqkit) | ✅ | n=… × 2, mean_len=… bp, N50=… | — |
| Platform (auto-detected) | ✅ | illumina | — |
| Coverage | ✅ | 87.5x | 50–200x sweet spot |
| Contamination (Kraken2) | ✅ | 97.3% Escherichia | >95% expected |
| Disk space | ✅ | 320 GB free | >50 GB |
| Tool availability | ✅ | all OK | — |
| Resource (host) | ✅ | 16 cores / 64 GB | >8 cores / >32 GB |

## Recommendations

- **Platform**: `illumina` (auto-detected; user-confirmed)
- **Assembler**: `spades` (with `--careful`)
- **Polishing**: `skip` (short-read-only; no long reads available)
- **Hide warnings**: <list, or "none">

## Tools

| Tool | Status | Notes |
|---|---|---|
| seqkit | OK | `/path/to/seqkit` |
| minimap2 | OK | `/path/to/minimap2` |
| samtools | OK | `/path/to/samtools` |
| kraken2 | OK | `/path/to/kraken2` |
| spades | OK | `/path/to/spades` |
| checkm-genome | GO-WITH-WARNINGS | pkg_resources trap; require `setuptools<81` |

## Handoff

If verdict is `GO` or `GO-WITH-WARNINGS`, hand off to:
- `assembly/short-read-assembly` (if platform = illumina)
- `assembly/long-read-assembly` (if platform = ont or pacbio-hifi)
- `assembly/hybrid-assembly` (if platform = hybrid)

If verdict is `NO-GO`, do NOT proceed — list the failing checks and ask the user to fix them.

## Reproducibility

- params.json: $RUN_DIR/params.json
- evidence:   $RUN_DIR/preflight_evidence.txt
- this report: $RUN_DIR/preflight.md (regenerable via this skill)
```

## Interpretation Guidelines

- **GO**: all evidence checks pass with confident values. Proceed to assembly.
- **GO-WITH-WARNINGS**: at least one check is in warning territory. Proceed but surface the warnings; consider the recommendations carefully.
- **NO-GO**: at least one check fails. **Stop** and ask the user to fix. Don't try to work around a `NO-GO`.

## Troubleshooting — Signature library

When preflight fails or produces unexpected output, match the failure against these patterns. **Always** read the actual error before concluding.

| Signature in stderr / log | Likely cause | Suggested fix |
| --- | --- | --- |
| `seqkit: command not found` | pixi env missing `seqkit` | `pixi add seqkit`. |
| `kraken2: database not found` | `KRAKEN2_DB_PATH` unset | `export KRAKEN2_DB_PATH="$SKILL_ROOT/assets/kraken2_db"` or download with `kraken2-build --db "$SKILL_ROOT/assets/kraken2_db" ...`. |
| `Kraken2: DB too large to download` | Limited disk space | Use `minikraken2` or `centrifuge` instead. |
| `minimap2: cannot find index` | Reference path wrong | Set `EXPECTED_GENOME_SIZE_MB` and skip reference-based coverage (use raw-base formula). |
| `ModuleNotFoundError: No module named 'pkg_resources'` | Python ≥ 3.12 + setuptools ≥ 81 | `pixi add 'setuptools<81'`. |
| `samtools: command not found` | pixi env missing `samtools` | `pixi add samtools`. |
| `bc: command not found` (rare on macOS) | macOS lacks `bc` by default | Use `python3 -c` or `awk` for the coverage formula. |
| Coverage estimate is 0 or wildly wrong | Empty FASTQ or wrong path | `zcat $RUN_DIR/cleaned_R1.fastq.gz \| head`; verify path. |
| Platform auto-detection gives `unknown` | All mean read lengths are between 100 bp and 1000 bp — unusual | Ask the user directly. |
| Tool availability check shows `MISSING` for a tool that's actually installed | pixi env not activated | Run `pixi shell` first, or use `pixi run --manifest-path ...` prefix. |
| Kraken2 reports top genus is not the expected one | Genuine contamination | Move to `GO-WITH-WARNINGS` or `NO-GO` depending on %. |

## Verification

- [ ] `$RUN_DIR/params.json` exists and is valid JSON.
- [ ] `$RUN_DIR/preflight.md` exists with overall verdict.
- [ ] `$RUN_DIR/preflight_evidence.txt` exists with raw tool outputs.
- [ ] Overall verdict is `GO` or `GO-WITH-WARNINGS` (not `NO-GO`) before proceeding to assembly.

## Output contract

This skill produces:

- `$RUN_DIR/params.json` (machine contract, consumed by `assembly/*`)
- `$RUN_DIR/preflight.md` (human audit, consumed by the orchestrator for the verdict gate)
- `$RUN_DIR/preflight_evidence.txt` (raw evidence, for debugging)

It does **not** produce any assembly artifact. The assembly sub-skills do that.

## What NOT to do

- Do **not** skip the evidence collection. Every recommendation in `params.json` must be cited back to a measured value in `preflight_evidence.txt`.
- Do **not** hand-write `params.json` without running the evidence collection first. The whole point of this skill is to derive parameters from data, not from the agent's memory.
- Do **not** override a `NO-GO` verdict. A `NO-GO` means the data is not ready — fix it upstream.
- Do **not** proceed to assembly if `preflight.md` is missing. The assembly sub-skills will refuse, but the orchestrator should also check.
- Do **not** re-run preflight without deleting `params.json` first — the existence of `params.json` is the stage-detection signal that preflight is done.
- Do **not** invent expected genome size defaults. If the user doesn't know, infer from a reasonable bacterial range (3–6 Mbp) and warn that the coverage estimate is approximate.
- Do **not** edit `pixi.toml` from this skill. The tool-availability check reports but does not fix.

## Handoff

After this skill writes `$RUN_DIR/preflight.md` and `$RUN_DIR/params.json`:

- **If verdict is `GO` or `GO-WITH-WARNINGS`** → hand off to the appropriate assembly sub-skill based on `params.json` `$platform`:
  - `illumina` → `assembly/short-read-assembly`
  - `ont` or `pacbio-hifi` → `assembly/long-read-assembly`
  - `hybrid` → `assembly/hybrid-assembly`
- **If verdict is `NO-GO`** → stop. List the failing checks and ask the user to fix them. Do NOT proceed to assembly.

The recommended message:

> Preflight complete. Overall verdict: `<verdict>`. Next: invoke `<assembly-sub-skill>` with `params.json` defaults (`$platform` = `…`, `$assembler` = `…`). preflight.md has the full evidence trail.
