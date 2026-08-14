---
name: hybrid-assembly
description: Combine short and long reads to assemble high-fidelity, complete bacterial genomes. This skill implements both Unicycler (short-read first) and Dragonflye (long-read first) strategies to resolve repeats and close gaps. Builds on the upstream read-qc-trimming skill. Has explicit ask-user stop points (SP13, SP14) that fire only when evidence is ambiguous.
version: 5.0.2
updated: "2026-08-14"
triggers:
  - "hybrid assembly"
  - "combine short and long reads"
  - "Unicycler"
  - "Dragonflye"
  - "complete bacterial genome"
  - "close gaps"
---

# Skill: hybrid-assembly

## Audience

This skill serves two purposes:
- **AI Agents**: Triggered by phrases like *"hybrid assembly"* or *"combine short and long reads"*. Must select Unicycler or Dragonflye based on the user's data quality profile.
- **Human Users**: Provides conceptual background, decision rationale, and troubleshooting guidance.

## When to Use This Skill

Use this skill if:
- You have **both short and long reads** (e.g., Illumina + ONT).
- You need the **highest possible accuracy** (uses both data types).
- You want to resolve **complex repeats** and close gaps.
- You are preparing a genome for **NCBI submission** (requires high-quality, closed assemblies).

Do NOT use this skill if:
- You only have one read type (use `short-read-assembly` or `long-read-assembly` instead).

## 0. Inputs / Outputs contract

This sub-skill **refuses to run** unless the upstream artifacts are present.

### Inputs (consumed)
| Path | Source | Required? |
| --- | --- | --- |
| `$RUN_DIR/cleaned_R1.fastq.gz` | `read-qc-trimming` | yes |
| `$RUN_DIR/cleaned_R2.fastq.gz` | `read-qc-trimming` | yes |
| `$RUN_DIR/cleaned_long.fastq.gz` | `read-qc-trimming` | yes |
| `$RUN_DIR/preflight.md` | `preflight/genome-input-preflight` | yes (verdict ≥ GO-WITH-WARNINGS) |
| `$RUN_DIR/params.json` | `preflight/genome-input-preflight` | yes (platform=hybrid + assembler recommendation) |

If `preflight.md` is missing or overall verdict is `NO-GO`, stop and tell the user: *"Run `preflight/genome-input-preflight` first; this skill refuses to assemble without a preflight verdict ≥ GO-WITH-WARNINGS."*

### Outputs (produced)
| Path | Owner | Format | Notes |
| --- | --- | --- | --- |
| `$RUN_DIR/draft.fasta` | `Unicycler` / `Dragonflye` / `Hybracter` | FASTA | Renamed from tool-native filename. Closed (circular) contigs expected. |

### Where to write
- Use `$RUN_DIR` (env var) or the current working directory if `$RUN_DIR` is unset.

## 0.5 Ask-User Stop Points

This sub-skill has **2 stop points** (SP13, SP14). Each fires only when the evidence is ambiguous. If the evidence is unambiguous, the agent auto-picks the default and proceeds silently.

### SP13 — Short-read coverage marginal + Unicycler chosen

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `params.json` `recommendations.assembler = unicycler` AND Illumina coverage < 50× | Unicycler's SPAdes step struggles with low short-read coverage | Ask: "Recommended assembler is Unicycler, but Illumina coverage is only `<X>×`. Unicycler needs ≥ 50× short reads for the SPAdes backbone. Pick: (A) proceed with Unicycler anyway (expect fragmented), (B) switch to Dragonflye (long-read first; works with low short coverage), (C) switch to Hybracter (modern automated wrapper), (D) abort" |

**Auto-pick when**: Illumina coverage ≥ 50×. Default: trust preflight.

### SP14 — Long-read coverage very low

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `params.json` long-read coverage < 20× | Hybrid assembly needs enough long reads to bridge repeats | Ask: "Long-read coverage is only `<X>×` — hybrid assembly needs ≥ 20× to reliably bridge repeats. Pick: (A) proceed with hybrid anyway (Unicycler may still work), (B) fall back to short-read-only assembly, (C) re-sequence to increase long-read depth, (D) abort" |

**Auto-pick when**: long-read coverage ≥ 20×. Default: trust preflight.

## Description

Assemble bacterial genomes using both short (Illumina) and long (ONT/PacBio) reads. This is the gold standard for producing "closed" genomes where chromosomes and plasmids are fully resolved without gaps. The `nf-core/bacass` pipeline supports two primary paradigms: Unicycler and Dragonflye.

> **Preflight guard.** Before running any assembly command, verify `preflight.md` overall verdict ≥ `GO-WITH-WARNINGS` and `params.json` indicates both short AND long read data (`$has_short = true` and `$has_long = true`). If `params.json` recommends a specific assembler (e.g. `unicycler` for low-coverage long reads, `dragonflye` for high-quality long reads, `hybracter` for automated modern), use that — the preflight evidence supports the choice.

## Conceptual Background

Hybrid assembly combines the strengths of both technologies:
- **Short reads**: High base-level accuracy ($Q30+$, $>99.9\%$ accuracy).
- **Long reads**: Long-range structural information (spans repeats).

**The Two Paradigms:**
1. **Short-Read First (Unicycler)**: Build a high-quality short-read assembly graph, then use long reads to scaffold and close gaps.
2. **Long-Read First (Dragonflye)**: Build a long-read assembly, then use short reads to correct base-level errors (polishing).

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**:
  - Cleaned short reads (`.fastq.gz`) produced by the `read-qc-trimming` skill.
  - Cleaned long reads (`.fastq.gz`) produced by the `read-qc-trimming` skill.
- **Required Tools**:
  - **Assembly**: `Unicycler` (Short-read first), `Dragonflye` (Long-read first), `Hybracter` (Automated modern).

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add unicycler dragonflye spades flye medaka pypolish pypolca hybracter
```

## Procedure

### 1. Strategy Selection

| Paradigm             | Recommended Tool | Why This Tool?                                                                                                                                  |
|:-------------------- |:---------------- |:------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Short-Read First** | `Unicycler`      | Excellent for low-coverage long reads. Uses SPAdes to build a high-quality short-read graph, then bridges contigs with long reads.              |
| **Long-Read First**  | `Dragonflye`     | Highly accurate for high-quality long reads. Uses Flye to build a long-read assembly, then polishes with short reads (Pypolish/Pypolca).        |
| **Automated / Modern** | `Hybracter`    | Scalable and updated for modern tools. Implements a long-read-first approach with automated polishing.                                          |

### 2. Execution

#### Path A: Unicycler (Short-Read First)
Unicycler is the most widely used hybrid assembler. It builds an SPAdes assembly graph, then bridges contigs using long reads.

```bash
mkdir -p "$RUN_DIR/unicycler_output"
unicycler -1 "$RUN_DIR/cleaned_R1.fastq.gz" \
          -2 "$RUN_DIR/cleaned_R2.fastq.gz" \
          -l "$RUN_DIR/cleaned_long.fastq.gz" \
          -o "$RUN_DIR/unicycler_output/" \
          -t 8
# Final result: $RUN_DIR/unicycler_output/assembly.fasta
cp "$RUN_DIR/unicycler_output/assembly.fasta" "$RUN_DIR/draft.fasta"
```
*Key Flags:*
- `-l`: Long reads (FastA/FastQ, gzipped supported).
- `--no_miniasm`: Skip the long-read assembly step if coverage is low.

#### Path B: Dragonflye (Long-Read First)
Dragonflye wraps Flye (or other long-read assemblers) and applies short-read polishing.

```bash
mkdir -p "$RUN_DIR/dragonflye_out"
dragonflye --reads "$RUN_DIR/cleaned_long.fastq.gz" \
           --R1 "$RUN_DIR/cleaned_R1.fastq.gz" \
           --R2 "$RUN_DIR/cleaned_R2.fastq.gz" \
           --outdir "$RUN_DIR/dragonflye_out/" \
           --assembler flye \
           --polish-rounds 3 \
           --threads 8
cp "$RUN_DIR/dragonflye_out/assembly.fasta" "$RUN_DIR/draft.fasta"
```

#### Path C: Hybracter (Automated Modern)
```bash
mkdir -p "$RUN_DIR/hybracter_out"
hybracter hybrid --reads-long "$RUN_DIR/cleaned_long.fastq.gz" \
                 --reads-short-r1 "$RUN_DIR/cleaned_R1.fastq.gz" \
                 --reads-short-r2 "$RUN_DIR/cleaned_R2.fastq.gz" \
                 --output "$RUN_DIR/hybracter_out/"
cp "$RUN_DIR/hybracter_out/finished_genomes/*.fasta" "$RUN_DIR/draft.fasta"
```

## Interpretation Guidelines

- **Closure**: Check for circular contigs. Unicycler, Dragonflye, and Hybracter all attempt to circularize the genome.
- **Consistency**: Ensure the total genome size matches the expected size for the organism.
- **Plasmids**: Pay special attention to plasmid reconstruction. Unicycler excels at separating plasmids with similar sequences.

## Troubleshooting — Signature library

| Signature in stderr / log | Likely cause | Suggested fix |
| --- | --- | --- |
| `Unicycler: no SPAdes output found` | SPAdes crashed (often OOM) | Reduce `-t` (threads) or subsample short reads; switch to `Dragonflye` (long-read first). |
| Unicycler runs very slowly | Low short-read coverage or excessive read count | Subsample short reads to $50\times$ coverage; reduce thread count if memory-bound. |
| `Unicycler: WARNING: 0 long reads passed filter` | Long-read length/quality filter too strict | Verify cleaned long reads: `seqkit stats cleaned_long.fastq.gz`. Re-run `read-qc-trimming` with relaxed filter. |
| Plasmids not circularized | Insufficient long-read coverage of plasmid; plasmid loss | Increase long-read depth; check for coverage uniformity. |
| Dragonflye produces fragmented assembly | Poor-quality long reads or insufficient coverage | Use `Filtlong` to filter low-quality reads; increase sequencing depth. |
| `Dragonflye: Racon not found` | pixi env missing `racon` | `pixi add racon`. |
| `Hybracter: cannot find bakta_db` | Bakta DB path env var unset | `export BAKTA_DB=/path/to/db` or pass `--bakta-db`. |
| `Hybracter: long-read subsampling failed` | Insufficient long-read coverage | Increase long-read input depth. |
| Misassemblies at repeat boundaries | Long-read errors or incorrect assembler parameters | Try the alternative paradigm (Unicycler vs. Dragonflye); increase coverage. |
| `Killed` (any tool, exit 137) | OOM | Subsample reads; switch to a less memory-hungry assembler; reduce threads. |

## Verification

- [ ] `$RUN_DIR/draft.fasta` exists.
- [ ] The assembly is validated for circularity where applicable (e.g., via Bandage or QUAST).
- [ ] Total assembly length matches the target species size.
- [ ] Plasmids are fully resolved or documented if fragmented.

## Output contract

This skill produces:

- `$RUN_DIR/draft.fasta` (renamed from the tool's native output)

It does **not** produce a `report.md`. The QC verdict is generated by `validation/assembly-qc` after polishing.

## What NOT to do

- Do **not** invoke this skill unless you have **both** short AND long reads. If you only have one, use `short-read-assembly` or `long-read-assembly` instead.
- Do **not** write the FASTA to a tool-default path. Always copy/rename to `$RUN_DIR/draft.fasta`.
- Do **not** run Unicycler with very high short-read coverage ($>1000\times$) without first subsampling — Unicycler's SPAdes step is memory-hungry.
- Do **not** skip the `mkdir -p` step before any tool's `--out-dir` (Unicycler, Dragonflye, Hybracter) — same Flye/SPAdes trap.
- Do **not** choose between Unicycler and Dragonflye without checking long-read quality first. If long reads are low-coverage ($<20\times$), Unicycler (short-read first) outperforms. If long reads are high-quality ($>50\times$, high Q-score), Dragonflye (long-read first) wins.

## Handoff

After this skill writes `$RUN_DIR/draft.fasta`:

- For Unicycler output → optional light polishing, then straight to `validation/assembly-qc`. Unicycler already incorporates short-read polishing internally.
- For Dragonflye / Hybracter output → mandatory `polishing/genome-polishing` (Dragonflye already runs Medaka + Pypolish, so verify its output before adding more polishing rounds).
- For Hybracter with `--skip-polish` → mandatory `polishing/genome-polishing`.

Say: *"Hybrid assembly written to `$RUN_DIR/draft.fasta`. Handing off to `<polishing or qc>`."*
