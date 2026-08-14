---
name: genome-polishing
description: Correct base-level errors in bacterial genome assemblies. This skill implements a multi-stage polishing sequence: long-read polishing (Medaka/NanoPolish) followed by short-read polishing (Pypolish/Pypolca) to achieve "perfect" nucleotide accuracy.
version: 5
updated: "2026-08-14"
triggers:
  - "polish genome"
  - "correct assembly errors"
  - "Medaka"
  - "NanoPolish"
  - "Pypolish"
  - "Pypolca"
  - "polish ONT assembly"
  - "polish hybrid assembly"
---

# Skill: genome-polishing

## Audience

This skill serves two purposes:
- **AI Agents**: Triggered by phrases like *"polish genome"* or *"correct assembly errors"*. Must execute the long-read $\rightarrow$ short-read polishing sequence and write `assembly.fasta` for the next phase.
- **Human Users**: Provides conceptual background, decision rationale, and troubleshooting guidance.

## When to Use This Skill

Use this skill if:
- You have a **long-read** or **hybrid** assembly that needs base-level correction.
- You need to achieve **"perfect" accuracy** ($>99.99\%$) for publication or submission.
- You observe **high INDEL rates** when mapping reads back to the assembly.

Do NOT use this skill if:
- You have a **short-read-only** assembly (polishing offers minimal benefit).
- Your assembly is from **PacBio HiFi** data (already $>99.9\%$ accurate; polishing is optional).

## 0. Inputs / Outputs contract

This sub-skill **refuses to run** unless the upstream artifacts are present.

### Inputs (consumed)
| Path | Source | Required? |
| --- | --- | --- |
| `$RUN_DIR/draft.fasta` | `assembly/long-read-assembly` or `assembly/hybrid-assembly` (or `assembly/short-read-assembly` for re-polish) | yes |
| `$RUN_DIR/cleaned_long.fastq.gz` | `read-qc-trimming` | yes (for Stage 1 long-read polish) |
| `$RUN_DIR/cleaned_R1.fastq.gz` | `read-qc-trimming` | yes (for Stage 2 short-read polish) |
| `$RUN_DIR/cleaned_R2.fastq.gz` | `read-qc-trimming` | yes (paired-end, for Stage 2) |

### Outputs (produced)
| Path | Owner | Format | Notes |
| --- | --- | --- | --- |
| `$RUN_DIR/assembly.fasta` | `Pypolca` (final stage) | FASTA | Polished, ready for QC. The next phase (`validation/assembly-qc`) reads this exact path. |
| `$RUN_DIR/medaka.fasta` | `Medaka` | FASTA | Intermediate, kept for signature-library matching. |
| `$RUN_DIR/polypolish.fasta` | `Polypolish` (intermediate) | FASTA | Intermediate. |
| `$RUN_DIR/polishing.log` | polishing tools | text | Free-form log, retained for downstream signature matching. |

### Where to write
- Use `$RUN_DIR` (env var) or the current working directory if `$RUN_DIR` is unset.

## Description

Genome polishing is the process of correcting errors (primarily INDELs and SNPs) in a draft assembly. This skill is mandatory for long-read and hybrid assemblies to reach "perfect" accuracy. It follows a strict sequence: **Long-read polishing $\rightarrow$ Short-read polishing**.

## Conceptual Background

**Why is polishing necessary?**
- Long reads (ONT) have a per-base error rate of $\approx 1\text{-}5\%$, dominated by INDELs in homopolymer regions.
- Even after consensus assembly (e.g., Autocycler), a small number of errors remain.
- These errors cause **frame-shifts** in genes, leading to incorrect annotation.

**The Two-Stage Paradigm:**
1. **Long-read polishing**: Uses the same long reads to correct large-scale errors. Coarse but structurally aware.
2. **Short-read polishing**: Uses highly accurate short reads ($Q30+$) to fix the remaining fine-scale errors.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**:
  - A draft assembly (`$RUN_DIR/draft.fasta`) from the assembly skills.
  - Long reads (`$RUN_DIR/cleaned_long.fastq.gz`) for long-read polishing.
  - Short reads (`$RUN_DIR/cleaned_R{1,2}.fastq.gz`) for short-read polishing (mandatory for hybrid/high-quality workflows).
- **Required Tools**:
  - **Long-read Polishing**: `Medaka`, `NanoPolish` (requires Fast5).
  - **Short-read Polishing**: `Pypolish`, `Pypolca`.
  - **Short-read Mapping**: `BWA-MEM2` or `MINIMAP2` (for polishing prep).

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add medaka nanopolish polypolish pypolca bwa-mem2 minimap2 samtools
```

## Procedure

### 1. Stage 1: Long-Read Polishing (Coarse)
This step uses the same long reads used for assembly to correct large-scale errors and improve consensus.

#### Path A: Medaka (Standard ONT)
Medaka is a neural-network-based polishing tool for ONT reads.
```bash
# 1. Map reads to the assembly
mkdir -p "$RUN_DIR/medaka_tmp"
minimap2 -ax map-ont -t 8 "$RUN_DIR/draft.fasta" "$RUN_DIR/cleaned_long.fastq.gz" \
  | samtools sort -o "$RUN_DIR/medaka_tmp/mapped.bam" -
samtools index "$RUN_DIR/medaka_tmp/mapped.bam"

# 2. Run Medaka
medaka_consensus -i "$RUN_DIR/cleaned_long.fastq.gz" \
                 -d "$RUN_DIR/draft.fasta" \
                 -o "$RUN_DIR/medaka_output/" \
                 -t 8
# Result: $RUN_DIR/medaka_output/consensus.fasta
cp "$RUN_DIR/medaka_output/consensus.fasta" "$RUN_DIR/medaka.fasta"
```

#### Path B: NanoPolish (Requires Fast5)
NanoPolish is an older tool requiring signal-level data (Fast5).
```bash
nanopolish index -d fast5_dir/ "$RUN_DIR/cleaned_long.fastq.gz"
bwa-mem2 -x ont2d "$RUN_DIR/draft.fasta" "$RUN_DIR/cleaned_long.fastq.gz" \
  | samtools sort -o mapped.bam -
samtools index mapped.bam
nanopolish variants --consensus polished.fasta -p 8 -b mapped.bam -g "$RUN_DIR/draft.fasta"
```

### 2. Stage 2: Short-Read Polishing (Fine)

Short reads have much higher base-level accuracy and are used to "clean up" the remaining errors.

#### Path A: Pypolish (Iterative, Recommended)
Pypolish iteratively aligns short reads and corrects the consensus.
```bash
# 1. Index the assembly
bwa-mem2 index "$RUN_DIR/medaka.fasta"

# 2. Map reads
bwa-mem2 -t 8 "$RUN_DIR/medaka.fasta" \
              "$RUN_DIR/cleaned_R1.fastq.gz" \
              "$RUN_DIR/cleaned_R2.fastq.gz" \
  | samtools sort -o "$RUN_DIR/polypolish_tmp/mapped.bam" -
samtools index "$RUN_DIR/polypolish_tmp/mapped.bam"

# 3. Run Pypolish
polypolish filter --in "$RUN_DIR/polypolish_tmp/mapped.bam" --out "$RUN_DIR/polypolish_tmp/filtered.bam"
polypolish polish --assembly "$RUN_DIR/medaka.fasta" \
                  --in "$RUN_DIR/polypolish_tmp/filtered.bam" \
                  --out "$RUN_DIR/polypolish.fasta"
```

#### Path B: Pypolca (Single-Pass, Faster)
Use `Pypolca --careful` to avoid over-correcting real biological variation. Pypolca is the recommended **final** polish step because it runs in a single pass.

```bash
# Pypolca can take the medaka output (Path A) OR polypolish output (Path A alt).
# Use whichever Stage-1+intermediate-stage output you have.

bwa-mem2 index "$RUN_DIR/medaka.fasta"
bwa-mem2 -t 8 "$RUN_DIR/medaka.fasta" \
              "$RUN_DIR/cleaned_R1.fastq.gz" \
              "$RUN_DIR/cleaned_R2.fastq.gz" \
  | samtools sort -o "$RUN_DIR/pypolca_tmp/mapped.bam" -
samtools index "$RUN_DIR/pypolca_tmp/mapped.bam"

pypolca run -a "$RUN_DIR/medaka.fasta" \
            -o "$RUN_DIR/assembly.fasta" \
            -r -t 8 "$RUN_DIR/pypolca_tmp/mapped.bam"
# Final result: $RUN_DIR/assembly.fasta
```

## Interpretation Guidelines

- **Error Reduction**: Compare the number of INDELs before and after polishing by mapping reads back and checking mismatch rates.
- **Base-level Accuracy**: Polishing should move the assembly from $\approx 95\text{-}99\%$ accuracy to $> 99.99\%$.
- **Over-polishing**: Be cautious of removing rare variants. Use Pypolca's `careful` mode or verify against the raw read mapping.

## Troubleshooting — Signature library

When polishing fails or regresses quality, match the failure against these patterns. **Always** read the actual error before concluding — never pattern-match blindly.

| Signature in stderr / log | Likely cause | Suggested fix |
| --- | --- | --- |
| `medaka_consensus: command not found` | pixi env missing `medaka` | `pixi add medaka`. |
| Medaka fails with memory error | Very large genome or excessive coverage | Subsample long reads with `Rasusa` before polishing. |
| `Medaka: model not found for chemistry X` | Outdated Medaka model | Update pixi env; specify model manually: `medaka_consensus -m r1041_e82_400bps_hac_v4.2.0`. |
| Polishing on R10.4.1 chemistry fails with default model | Default model is for older chemistry | Specify R10.4.1 model manually (see above). |
| NanoPolish requires Fast5 files | Newer basecallers output Pod5 instead of Fast5 | Convert Pod5 to Fast5, or use `Dorado polish` instead of NanoPolish. |
| `nanopolish: command not found` | pixi env missing `nanopolish` | `pixi add nanopolish`. |
| Polishing introduces errors (regressions) | Over-polishing or incorrect read mapping | Use `Pypolca --careful`; reduce polishing rounds. |
| Short-read polishing has no effect | Insufficient short-read coverage ($<20\times$) | Ensure short-read coverage is $>20\times$; check mapping rates. |
| `Pypolca: freebayes: command not found` | pixi env didn't install `freebayes` (transitive dep of `pypolca`) | `pixi add freebayes`. |
| `samtools: cannot index .bam` (BamFile not indexed) | `samtools` < 1.18 conflict | Confirm `pixi.toml` pins `samtools >= 1.18`. |
| `polypolish: No reads aligned` | Wrong assembly index or reads not cleaned | Re-run `read-qc-trimming`; verify FASTQ headers match assembly contigs. |
| `BWA-MEM2: cannot open index` | Index file missing | Run `bwa-mem2 index <assembly.fasta>` first. |
| `minimap2: huge memory` | Very long reads + many of them | Subsample reads with `seqkit sample -n 50000`. |
| `Killed` (exit 137) during any polish step | OOM | Subsample reads; reduce `-t` (threads). |
| `Assembly has 0 contigs` after Pypolca | Upstream Medaka assembly failed | Check `$RUN_DIR/medaka.fasta`; re-run from `$RUN_DIR/draft.fasta`. |

## Verification

- [ ] Polishing sequence followed: Long-read $\rightarrow$ Short-read.
- [ ] `$RUN_DIR/assembly.fasta` exists.
- [ ] For short-read polishing, a minimum coverage (usually $> 20\times$) was verified.

## Output contract

This skill produces:

- `$RUN_DIR/assembly.fasta` (the polished assembly, ready for QC)
- `$RUN_DIR/medaka.fasta`, `$RUN_DIR/polypolish.fasta`, `$RUN_DIR/polishing.log` (intermediates, retained for signature matching)

It does **not** produce a `report.md`. The QC verdict is generated by `validation/assembly-qc`.

## What NOT to do

- Do **not** polish in the wrong order. The mandatory sequence is **long-read polish first, then short-read polish**. Reversing the order produces over-corrections from short reads and loses long-read structural information.
- Do **not** skip the BWA-MEM2 indexing step before mapping. `bwa-mem2 index` is required.
- Do **not** run short-read polishing with Pypolish's `polish` step on an unfiltered BAM — always run `polypolish filter` first to remove ambiguous alignments.
- Do **not** polish a short-read-only assembly. It offers marginal benefit and risks introducing errors from over-correction.
- Do **not** polish a PacBio HiFi assembly multiple times. HiFi reads are already $>99.9\%$ accurate; one round is enough, more is over-correction.
- Do **not** write the final polished FASTA to a tool-default path. Always end with `$RUN_DIR/assembly.fasta` — that is the path `validation/assembly-qc` reads.

## Handoff

After this skill writes `$RUN_DIR/assembly.fasta`:

- Hand off to `validation/assembly-qc`. It will run CheckM, QUAST, BUSCO, and Kraken2 against `$RUN_DIR/assembly.fasta` and write `$RUN_DIR/report.md`.
- The agent should say: *"Polished assembly written to `$RUN_DIR/assembly.fasta`. Handing off to `validation/assembly-qc` — it will write `report.md` with pass/warn/fail verdicts."*
