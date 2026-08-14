---
name: long-read-assembly
description: Assemble bacterial genomes from long-read sequencing data (ONT/PacBio). This skill implements the consensus assembly paradigm to resolve repeats and produce near-complete circular chromosomes and plasmids, integrating quality filtering and depth downsampling. Builds on the upstream read-qc-trimming skill.
version: 5
updated: "2026-08-14"
triggers:
  - "assemble long reads"
  - "nanopore assembly"
  - "pacbio assembly"
  - "Flye"
  - "Raven"
  - "Canu"
  - "Miniasm"
  - "Racon"
  - "Autocycler"
  - "Dragonflye"
  - "long-read bacterial assembly"
---

# Skill: long-read-assembly

## Audience

This skill serves two purposes:
- **AI Agents**: Triggered by phrases like *"assemble long reads"* or *"nanopore assembly"*. Must execute the strategy selection and verification steps below, and produce a circularized draft for `polishing/genome-polishing` to consume.
- **Human Users**: Provides conceptual background, decision rationale, and troubleshooting guidance.

## When to Use This Skill

Use this skill if:
- You have **long-read data** (ONT or PacBio HiFi).
- You need a **complete, closed genome** (single contig per replicon).
- You are working with a **highly repetitive** genome (long reads span repeats).
- You need to resolve **plasmids** or other extrachromosomal elements.

Do NOT use this skill if:
- You only have Illumina short reads (use `short-read-assembly` instead).
- You have both short and long reads (use `hybrid-assembly` for the highest accuracy).
- You need extreme base-level accuracy without short-read polishing (this skill assumes polishing will follow).

## 0. Inputs / Outputs contract

This sub-skill **refuses to run** unless the upstream artifacts are present.

### Inputs (consumed)
| Path | Source | Required? |
| --- | --- | --- |
| `$RUN_DIR/cleaned_long.fastq.gz` | `read-qc-trimming` | yes |

### Outputs (produced)
| Path | Owner | Format | Notes |
| --- | --- | --- | --- |
| `$RUN_DIR/draft.fasta` | `Flye` / `Autocycler` / `Dragonflye` | FASTA | Renamed from tool-native filename. Circular contigs expected for closed genomes. |
| `$RUN_DIR/draft.log` | assembly tool | text | Free-form log (kept for the QC skill's signature-library match). |

### Where to write
- Use `$RUN_DIR` (env var) or the current working directory if `$RUN_DIR` is unset.
- The next phase (`polishing/genome-polishing`) looks for `$RUN_DIR/draft.fasta`.

## Description

Assemble bacterial genomes from long-read sequencing data. This skill moves beyond simple assembly by implementing a consensus approach (via Autocycler or Dragonflye) to minimize structural errors and maximize contiguity.

## Conceptual Background

Long-read assemblers use the **Overlap-Layout-Consensus (OLC)** or **de Bruijn-like graph (e.g., Flye)** paradigms:
1. **Overlap**: Find overlaps between all reads (since reads can span repeats).
2. **Layout**: Arrange reads into a graph structure (e.g., a string graph).
3. **Consensus**: Generate the consensus sequence from the aligned reads.

**Why does this produce complete genomes?** Long reads ($>10,000$ bp) are longer than most bacterial repeats (e.g., rRNA operons), allowing the assembler to span repetitive regions and produce a single contig per chromosome or plasmid.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: Cleaned long reads (`.fastq.gz`) produced by the `read-qc-trimming` skill.
- **Required Tools**:
  - **Assembly**: `Flye`, `Raven`, `Canu`, `Miniasm` + `Racon`.
  - **Consensus**: `Autocycler`, `Dragonflye`.

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add flye raven canu miniasm racon autocycler dragonflye
```

## Procedure

### 1. Primary Assembly (The Draft)
The agent selects an assembler based on data type and memory constraints.

| Read Type                | Recommended Tool | Why This Tool?                                                                                                                                                  |
|:------------------------ |:---------------- |:----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **ONT / PacBio (Standard)** | `Flye`           | Extremely robust for noisy long reads; excellent for plasmids. Uses repeat graphs to resolve ambiguities.                                                       |
| **ONT (Fast/Low RAM)**   | `Raven`          | Very fast and low memory. Ideal for high-throughput ONT datasets.                                                                                              |
| **PacBio (HiFi)**        | `Flye --pacbio-hifi` | Optimized for the high accuracy of HiFi reads; produces highly accurate assemblies.                                                                         |
| **ONT (High Accuracy)**  | `Canu`           | Legacy gold standard; uses adaptive k-mer weighting. High memory usage ($>30$ GB RAM for large genomes).                                                        |
| **Minimal Memory**       | `Miniasm` + `Racon` | Sketch-based assembly. Extremely fast but requires extensive polishing (multiple Racon rounds).                                                                |

**Example (Flye):**
```bash
# CRITICAL: Flye does NOT recursively create nested output directories.
# If --out-dir has a parent that doesn't exist yet (e.g. assembly/flye/),
# Flye crashes with FileNotFoundError instead of creating it. mkdir -p first
# (verified 2026-08-14).
mkdir -p "$RUN_DIR/flye_output"

flye --nano-raw "$RUN_DIR/cleaned_long.fastq.gz" \
     --out-dir "$RUN_DIR/flye_output/" \
     --threads 8 \
     --genome-size 3m
# Result: $RUN_DIR/flye_output/assembly.fasta

# Normalize the path for the next phase:
cp "$RUN_DIR/flye_output/assembly.fasta" "$RUN_DIR/draft.fasta"
```

### 2. Consensus Assembly (The Refinement)

To avoid the "single-assembler bias" and structural errors, the agent MUST use a consensus tool.

#### Path A: Autocycler (Standard Paradigm)
`Autocycler` is the successor to Trycycler. It generates multiple assembly attempts and finds the most consistent consensus.

```bash
mkdir -p "$RUN_DIR/autocycler_out"

# Subsample reads (Autocycler requires multiple subsets)
autocycler subsample --reads "$RUN_DIR/cleaned_long.fastq.gz" \
                     --out_dir "$RUN_DIR/autocycler_out/"

# Run multiple primary assemblies (e.g., Flye, Raven, Miniasm+Racon)
# Then combine into a consensus:
autocycler combine --assemblies all_assemblies/*.fasta \
                   --out_dir "$RUN_DIR/autocycler_out/combined/"
autocycler resolve --inputs "$RUN_DIR/autocycler_out/combined/" \
                   --out_dir "$RUN_DIR/autocycler_out/resolved/"
# Final result: $RUN_DIR/autocycler_out/resolved/consensus.fasta
cp "$RUN_DIR/autocycler_out/resolved/consensus.fasta" "$RUN_DIR/draft.fasta"
```

#### Path B: Dragonflye (Automated Wrappers)
`Dragonflye` is an automated wrapper for long-read assembly using Flye + Medaka + Polypolish/Pypolca.
```bash
mkdir -p "$RUN_DIR/dragonflye_out"
dragonflye --reads "$RUN_DIR/cleaned_long.fastq.gz" \
           --outdir "$RUN_DIR/dragonflye_out/" \
           --assembler flye --polish-rounds 3
cp "$RUN_DIR/dragonflye_out/assembly.fasta" "$RUN_DIR/draft.fasta"
```

## Interpretation Guidelines

- **Circularization**: Check if the assembly reports circular chromosomes or plasmids. This is the goal for bacterial genomes.
- **Contig Count**: A "perfect" assembly has one contig per replicon (chromosome + plasmids).
- **N50**: For a single circular chromosome, the N50 will be approximately the genome size.

## Troubleshooting — Signature library

When assembly fails, match the failure against these patterns. **Always** read the actual error before concluding — never pattern-match blindly.

| Signature in stderr / log | Likely cause | Suggested fix |
| --- | --- | --- |
| `FileNotFoundError: [Errno 2] No such file or directory: '<out-dir>/...'` | `--out-dir` parent dir missing | `mkdir -p` first (verified 2026-08-14). |
| `Flye: ERROR: Inconsistent edge length` | Mix of read chemistries | Use only one chemistry; re-basecall with the same model. |
| Flye `Killed` (after long runtime, exit 137) | OOM | Subsample reads with `Rasusa` to $50{-}100\times$ coverage; reduce `--threads`. |
| `assembled contigs length: 0` | No reads passed upstream baiting/filtering | Verify `read-qc-trimming` output: `seqkit stats cleaned_long.fastq.gz`. Re-run with relaxed length filter. |
| Flye fails to circularize plasmids | Plasmid loss or coverage gaps in plasmid | Check coverage uniformity with `minimap2 + samtools depth`; increase long-read depth. |
| `Canu: ERROR: Can't find any sequences` | Wrong input format or empty FASTQ | Convert to gzipped FASTQ; verify with `seqkit head`. |
| `Canu: corrected coverage too low` | Insufficient input coverage | Subsample reads more aggressively? No — that's the wrong direction. Re-sequence or accept lower quality. |
| `Racon: Segmentation fault` | Insufficient memory or huge alignments | Bump pixi env memory; subset reads with `seqkit sample -n 50000` first. |
| `minimap2: command not found` | Env not activated | Verify pixi env: `pixi run --manifest-path $RUN_DIR/../pixi.toml which minimap2`. |
| `Autocycler: cannot combine, inputs differ in size` | Assemblies used different read subsets | Re-run all primary assemblies on the same `cleaned_long.fastq.gz`. |
| `Autocycler combine: 0 clusters formed` | All input assemblies are too divergent | Verify each assembly individually with `seqkit stats`; remove any that failed. |
| `Dragonflye: unsupported assembler X` | Outdated Dragonflye | Update pixi env: `pixi add dragonflye --update`. |
| `Oops, something went wrong` (Flye, no traceback) | Corrupted FASTQ | Re-download / re-basecall; check FASTQ with `seqkit stats`. |
| High memory usage / OOM with Flye | Very high coverage ($>100\times$) or very long reads | Subsample reads using `Rasusa` to a target coverage of $50\text{-}100\times$. |
| Multiple contigs instead of one circular chromosome | Incomplete assembly; coverage gaps or repeat resolution failure | Increase sequencing depth; try `Autocycler` for consensus. |
| Consensus assembly (Autocycler) fails | Inconsistent input assemblies (different parameters) | Ensure all input assemblies use the same read set; check Autocycler logs. |

## Verification

- [ ] `$RUN_DIR/draft.fasta` exists.
- [ ] Primary assembly (Flye/Raven) exists.
- [ ] Consensus assembly (`Autocycler` or `Dragonflye`) exists.
- [ ] The agent has verified that circularization was attempted.

## Output contract

This skill produces:

- `$RUN_DIR/draft.fasta` (renamed from the tool's native output)
- `$RUN_DIR/draft.log` (assembly tool's log, retained for signature-library matching downstream)

It does **not** produce a `report.md`. The QC verdict is generated by `validation/assembly-qc` after polishing.

## What NOT to do

- Do **not** skip the `mkdir -p` before Flye's `--out-dir`. Flye will crash silently on a missing parent (verified 2026-08-14).
- Do **not** run Flye at $200\times+$ coverage without subsampling — OOM is the #1 failure mode.
- Do **not** rely on a single primary assembler. Use `Autocycler` (or `Dragonflye`) to combine multiple assemblies and reduce single-assembler bias.
- Do **not** forget that long-read assemblies **always need polishing** — ONT reads have $1{-}5\%$ per-base error dominated by INDELs. Skip polishing and you get frame-shifts in genes.
- Do **not** write the FASTA to a tool-default path (`./flye_output/assembly.fasta`) and leave it there. Always copy/rename to `$RUN_DIR/draft.fasta`.
- Do **not** use `Canu` on a memory-constrained workstation ($<30$ GB). Switch to `Raven` or `Miniasm+Racon`.

## Handoff

After this skill writes `$RUN_DIR/draft.fasta`:

- **Always** hand off to `polishing/genome-polishing` for long-read assemblies — polishing is mandatory, not optional.
- The polishing skill looks for `$RUN_DIR/draft.fasta` and uses `$RUN_DIR/cleaned_long.fastq.gz` for back-mapping.
- If the user also has short reads, the polishing skill will run the Long $\rightarrow$ Short sequence automatically.

Say: *"Long-read assembly written to `$RUN_DIR/draft.fasta`. Handing off to `polishing/genome-polishing` — polishing is mandatory for long-read assemblies."*
