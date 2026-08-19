---
name: short-read-assembly
description: Assemble bacterial genomes from short-read sequencing data (Illumina). This skill focuses on producing the most contiguous draft possible from paired-end reads, utilizing De Bruijn graph assemblers and integrating quality control to ensure data integrity before assembly. Builds on the upstream read-qc-trimming skill. Has explicit ask-user stop points (SP8, SP9) that fire only when evidence is ambiguous.
version: 5.0.2
updated: "2026-08-14"
triggers:
  - "assemble short reads"
  - "illumina assembly"
  - "SPAdes"
  - "SKESA"
  - "MEGAHIT"
  - "bacterial assembly short-read"
  - "Unicycler short reads"
---

# Skill: short-read-assembly

## Audience

This skill serves two purposes:
- **AI Agents**: Triggered by phrases like *"assemble short reads"* or *"illumina assembly"*. Must execute the strategy selection and verification steps below, and write `Kraken2` contamination results next to the assembly.
- **Human Users**: Provides conceptual background, decision rationale, and troubleshooting guidance.

## When to Use This Skill

Use this skill if:
- You only have **Illumina short reads** (paired-end, $\le 300$ bp).
- You need a quick draft for variant calling or SNP analysis.
- You have **metagenomic** data and need to bin contigs into species-level bins.

Do NOT use this skill if:
- You have long-read data (use `long-read-assembly` instead).
- You have both short and long reads (use `hybrid-assembly` for the best results).
- You need a completely closed genome (short reads cannot span long repeats).

## 0. Inputs / Outputs contract

This sub-skill **refuses to run** unless the upstream artifacts are present.

### Inputs (consumed)
| Path | Source | Required? |
| --- | --- | --- |
| `$RUN_DIR/cleaned_R1.fastq.gz` | `read-qc-trimming` | yes |
| `$RUN_DIR/cleaned_R2.fastq.gz` | `read-qc-trimming` | yes (paired-end) |
| `$RUN_DIR/preflight.md` | `preflight/genome-input-preflight` | yes (verdict ≥ GO-WITH-WARNINGS) |
| `$RUN_DIR/params.json` | `preflight/genome-input-preflight` | yes (platform + assembler recommendation) |

If cleaned reads are not at those paths, stop and tell the user: *"Run the `read-qc-trimming` skill first; this skill assumes cleaned reads as input."*

If `preflight.md` is missing or overall verdict is `NO-GO`, stop and tell the user: *"Run `preflight/genome-input-preflight` first; this skill refuses to assemble without a preflight verdict ≥ GO-WITH-WARNINGS."*

### Outputs (produced)
| Path | Owner | Format | Notes |
| --- | --- | --- | --- |
| `$RUN_DIR/draft.fasta` | `spades.py` / `skesa` / `megahit` | FASTA | Renamed from the tool's native filename so the next phase can find it |
| `$RUN_DIR/kraken2_report.txt` | `kraken2` | TSV | Contamination screen (Acceptance: $>95\%$ of contigs align to expected genus) |

### Where to write
- Use `$RUN_DIR` (env var) or the current working directory if `$RUN_DIR` is unset.
- The next phase (`polishing/genome-polishing`) looks for `$RUN_DIR/draft.fasta`. **Never** write to `$RUN_DIR/..` or anywhere outside `$RUN_DIR`.

## 0.5 Ask-User Stop Points

This sub-skill has **2 stop points** (SP8, SP9). Each fires only when the evidence is ambiguous. If the evidence is unambiguous, the agent auto-picks the default and proceeds silently.

### SP8 — Coverage is marginal (< 30× for Illumina)

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `params.json` `coverage.estimated_x` < 30 for Illumina | MIMAG threshold is 30×; below this is `NO-GO` territory | Ask: "Illumina coverage is `<X>×` — MIMAG recommends ≥ 30×. Pick: (A) continue anyway (expect fragmented assembly), (B) re-sequence to increase coverage (recommended), (C) abort" |

**Auto-pick when**: coverage ≥ 30×. No ask.

### SP9 — Memory insufficient for the recommended assembler

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `params.json` `recommendations.assembler = spades` AND host RAM < 16 GB | SPAdes is memory-hungry | Ask: "Recommended assembler is SPAdes, but the host has only `<X> GB` RAM. SPAdes typically OOMs below 16 GB. Pick: (A) switch to SKESA (lower memory), (B) subsample reads to reduce peak memory, (C) proceed with SPAdes anyway and accept OOM risk, (D) abort" |

**Auto-pick when**: RAM ≥ 16 GB OR user explicitly requested SPAdes in the brief. Default to "proceed if preflight already approved" (preflight would have flagged this; trust its verdict).

## Description

Assemble bacterial genomes from short-read sequencing data. Since short reads cannot resolve large repetitive regions (e.g., rRNA operons, mobile elements), the result is typically a fragmented draft. This skill transforms cleaned FASTQ files into a FASTA assembly following the **nf-core/bacass** paradigm.

> **Preflight guard.** Before running any assembly command, verify `preflight.md` overall verdict ≥ `GO-WITH-WARNINGS` and `params.json` `$platform` is `illumina` (or `unknown`, in which case default to `spades`). If `params.json` recommends a different assembler (e.g. `skesa` for speed, `megahit` for metagenomes), use that — the preflight evidence supports the choice.

## Conceptual Background

Short-read assemblers use the **De Bruijn Graph** paradigm:
1. All reads are broken into **k-mers** (subsequences of length $k$).
2. Identical k-mers form nodes in a graph.
3. Overlapping k-mers (sharing $k-1$ bases) form edges.
4. The genome is reconstructed by finding an Eulerian path through the graph.

**Why does this produce fragmented assemblies?** Bacterial genomes contain long repetitive elements (e.g., rRNA operons of $5,000+$ bp). Since short reads (150-300 bp) are much shorter than these repeats, they cannot uniquely resolve them, causing the assembler to break the genome at each repeat boundary.

## Prerequisites

- **Environment**: Active environment with required tools (`pixi.toml` from the parent meta-skill).
- **Upstream Evidence**: Cleaned reads (`.fastq.gz`) produced by the `read-qc-trimming` skill.

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add spades skesa megahit kraken2
```

## Procedure

### 1. Strategy Selection

| Data Type / Goal                 | Recommended Tool              | Why This Tool?                                                                                                                                            |
|:-------------------------------- |:----------------------------- |:----------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Standard (High Contiguity)**   | `SPAdes`                      | The community standard for small genomes. Uses multi-size De Bruijn graphs to handle variable coverage. The `--careful` flag adds mismatch correction. |
| **High-Throughput / Fast**       | `SKESA`                       | Significantly faster and lower memory than SPAdes. Uses a greedy assembly approach that avoids some SPAdes artifacts.                                    |
| **Metagenomes / Large Inputs**   | `MEGAHIT`                     | Specifically optimized for large, complex datasets (metagenomes). Uses succinct De Bruijn graphs to reduce memory.                                        |
| **Hybrid (requires long reads)** | `Unicycler` (Short-read mode) | Optimizes SPAdes k-mers and bridges contigs with long reads (refer to `hybrid-assembly` skill).                                                           |

### 2. Execution

#### Path A: SPAdes (Standard)

SPAdes uses a multi-k-mer approach to resolve complex genomic regions.

```bash
# CRITICAL: SPAdes --out-dir must exist before invocation, OR spades.py will crash
# with "FileNotFoundError" (verified 2026-08-14, same trap as Flye — see long-read skill).
mkdir -p "$RUN_DIR/spades_output"

spades.py --careful \
          -t 8 \
          -1 "$RUN_DIR/cleaned_R1.fastq.gz" \
          -2 "$RUN_DIR/cleaned_R2.fastq.gz" \
          -o "$RUN_DIR/spades_output/"
# Final assembly: $RUN_DIR/spades_output/scaffolds.fasta

# Normalize the path for the next phase:
cp "$RUN_DIR/spades_output/scaffolds.fasta" "$RUN_DIR/draft.fasta"
```

*Note: The `--careful` flag reduces misassemblies by performing mismatch correction.*

#### Path B: SKESA (Fast)

```bash
skesa --reads "$RUN_DIR/cleaned_R1.fastq.gz" "$RUN_DIR/cleaned_R2.fastq.gz" \
      --cores 8 --output "$RUN_DIR/draft.fasta"
```

#### Path C: MEGAHIT (Large/Complex)

```bash
mkdir -p "$RUN_DIR/megahit_output"
megahit -1 "$RUN_DIR/cleaned_R1.fastq.gz" -2 "$RUN_DIR/cleaned_R2.fastq.gz" \
        -o "$RUN_DIR/megahit_output/" -t 8
# Final assembly: $RUN_DIR/megahit_output/final.contigs.fa
cp "$RUN_DIR/megahit_output/final.contigs.fa" "$RUN_DIR/draft.fasta"
```

### 3. Contamination Verification (The Gate)

Before proceeding to polishing (if applicable) or annotation, the assembly MUST be checked for contamination.

```bash
kraken2 --db "${KRAKEN2_DB_PATH:-$SKILL_ROOT/assets/kraken2_db}" --threads 8 \
        --output "$RUN_DIR/kraken2.out" \
        --report "$RUN_DIR/kraken2_report.txt" \
        --confidence 0.05 \
        "$RUN_DIR/draft.fasta"
```

- **Acceptance Criteria**: $>95\%$ of contigs must align to the expected genus.

## Interpretation Guidelines

- **Contiguity**: Check the number of contigs. A high number of contigs is expected for short-read only assemblies (typically $50\text{-}500+$ contigs for a bacterial genome).
- **N50**: Use as a rough proxy for assembly quality (higher is better). For a typical bacterial genome, an N50 of $>50,000$ bp is reasonable.
- **Misassemblies**: SPAdes `--careful` mitigates this; check QUAST for misassembly metrics.

## Troubleshooting — Signature library

When assembly fails, match the failure against these patterns. **Always** read the actual error before concluding — never pattern-match blindly.

| Signature in stderr / log | Likely cause | Suggested fix |
| --- | --- | --- |
| `spades.py: error: argument --out-dir: ... does not exist` | `--out-dir` parent directory missing | `mkdir -p` first (verified 2026-08-14, same trap as Flye). |
| `IO Error: Unable to read` followed by gz/bz2 error | Corrupted gzipped FASTQ | Re-run `read-qc-trimming`; verify with `seqkit stats`. |
| `Killed` (after long runtime, exit code 137) | OOM (SPAdes on huge input) | Subsample reads to target $50\times$ coverage with `seqkit sample`; or switch to `SKESA` (lower memory). |
| `SPAdes: WARN: Read error correction was skipped due to lack of memory` | Inadequate memory budget | Bump pixi env memory or switch to `--careful` off; reduce `-t`. |
| `SKESA: out of memory` (rare) | Pathological coverage | Subsample reads with `seqkit sample -p 0.5`. |
| `MEGAHIT: ERROR: empty input` | Wrong path or empty FASTQ | Verify cleaned reads exist and are non-empty: `zcat R1.fq.gz \| head`. |
| Kraken2: $>5\%$ contigs assigned to unexpected genus | Contamination in input DNA or library prep issue | Filter contaminating contigs; if pervasive, re-extract DNA or re-prep library. |
| Very high contig count ($>500$) | Low coverage or poor-quality reads | Re-evaluate upstream QC; ensure coverage is $>30\times$. |
| Assembly length much larger than expected | Contamination from another organism | Run `Kraken2` and filter out contaminating contigs. |
| Assembly length much smaller than expected | Aggressive trimming or failed assembly | Reduce QC stringency; check for adapter contamination. |
| Many misassemblies reported by QUAST | Repetitive regions or heterozygous sites (if not haploid) | Use `--careful` mode (SPAdes); consider downsampling or hybrid assembly. |
| `Kraken2 database not found` | DB path missing or `KRAKEN2_DB_PATH` env var unset | `export KRAKEN2_DB_PATH="$SKILL_ROOT/assets/kraken2_db"`; download with `kraken2-build --db "$SKILL_ROOT/assets/kraken2_db" --download-taxonomy`. |
| `Kraken2 database too large to download` | Limited disk space | Use a smaller database (e.g. `minikraken2`) or `centrifuge` instead. |

## Verification

- [ ] `$RUN_DIR/draft.fasta` exists.
- [ ] The total assembly length is approximately equal to the expected genome size of the species.
- [ ] `Kraken2` report (`$RUN_DIR/kraken2_report.txt`) confirms the sample matches the expected organism.

## Output contract

This skill produces:

- `$RUN_DIR/draft.fasta` (renamed from the tool's native output)
- `$RUN_DIR/kraken2_report.txt` (contamination screen)

It does **not** produce a `report.md`. The QC verdict is generated by `validation/assembly-qc`, which runs after polishing.

## What NOT to do

- Do **not** run SPAdes on raw reads — always go through `read-qc-trimming` first.
- Do **not** skip the `mkdir -p` before `--out-dir` — both `spades.py` and `flye` will crash silently on a missing parent dir.
- Do **not** run SPAdes without `--careful` on a bacterial isolate — `--careful` adds mismatch correction and is the standard for isolate genomes.
- Do **not** trust a "successful" assembly that has $>5\%$ Kraken2 contamination at the genus level. That is a real failure, not a soft warning.
- Do **not** write the FASTA to a tool-default path (`./scaffolds.fasta`, `./final.contigs.fa`) and leave it there. Always copy/rename to `$RUN_DIR/draft.fasta` so the next phase can find it.
- Do **not** invoke `polishing/genome-polishing` on a short-read-only assembly. Polishing offers minimal benefit and can introduce regressions (see polishing skill §When to Use).

## Handoff

After this skill writes `$RUN_DIR/draft.fasta`:

- If long-read data is also available → invoke `assembly/hybrid-assembly` (which can take both).
- Otherwise → invoke `polishing/genome-polishing` *only if* you also have short reads and want to do conservative short-read polishing on a hybrid context. For short-read-only, skip polishing and go straight to `validation/assembly-qc`.
- Either way, the agent should say: *"Draft assembly written to `$RUN_DIR/draft.fasta`. Handing off to `<next-skill>`."*
