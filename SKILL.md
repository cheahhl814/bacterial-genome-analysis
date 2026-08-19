---
name: bacterial-genome-analysis
description: End-to-end orchestration of bacterial genome reconstruction, from raw reads to a fully annotated, high-fidelity genomic sequence. This meta-skill integrates preflight (input validation), assembly, polishing, validation, and annotation into a strict evidence chain based on the nf-core/bacass paradigm. Use when the user wants to assemble, polish, validate, or annotate a bacterial genome — or when they ask "is my bacterial genome ready?". Builds on the upstream read-qc-trimming skill. Pairs with the bettamt-style ask-user stop point pattern from Betta-WGS-agent.
version: 5.1.0
updated: "2026-08-16"
triggers:
  - "assemble bacterial genome"
  - "complete bacterial assembly"
  - "bacterial genome pipeline"
  - "de novo bacterial assembly"
  - "annotate bacterial genome"
  - "hybrid bacterial assembly"
  - "is my bacterial genome ready"
  - "bacterial genome QC report"
---

# Meta-Skill: bacterial-genome-analysis

> **v5.1.0 — Adds a Nextflow runner (opt-in).** A thin Nextflow DSL2 wrapper now lives at [`runners/nextflow-runner/`](https://github.com/cheahhl814/bacterial-genome-analysis/tree/master/runners/nextflow-runner) for production / HPC / cohort runs. Bash remains the default and the source of truth. The runner mirrors nf-core/bacass and the [`nextflow-pipelines`](https://github.com/cheahhl814/nextflow-pipelines) style guide. See **§0.4** for the bash-vs-Nextflow decision matrix.
>
> **v5.0.2 redesign (predecessor).** Added the **Ask-User Stop Points** pattern, adopted from `Betta-WGS-agent` (betta-preflight's "validate with user or via command line inspection"). Every sub-skill with decision ambiguity now has explicit **SP1–SP19** stop points: each fires only when the evidence is ambiguous, each uses the **Evidence + Recommend + Options** format, and each lists the default (auto-pick) for the unambiguous case. The pipeline architecture is unchanged from v5.0.1 (Phase 0 Preflight + 4 phases).

## Audience

This meta-skill is designed to serve **two simultaneous audiences**:

1. **AI Coding Agents**: Triggered by the phrases above. The agent must execute the strict evidence chain, run the Go/No-Go gates, and write the `report.md` / `annotation-report.md` artifacts the sub-skills specify.
2. **Human Users (Bioinformaticians & Biologists)**: Read this document as a workflow guide. The sections explain *why* each phase exists and *what* trade-offs apply at each decision point.

## When to Use This Skill

Use this meta-skill when you need to:

- Reconstruct a bacterial genome **de novo** (without a reference genome).
- Achieve a **complete, closed** genome (single contig per replicon).
- Compare genomes or study population genetics (requires high-quality assemblies).
- Submit a genome to a public repository like NCBI (requires annotation).
- Identify antimicrobial resistance (AMR) genes, virulence factors, or metabolic pathways.

**Do NOT use this skill** if:

- You have a well-characterized reference genome (use a reference-based variant calling pipeline instead).
- You are analyzing eukaryotic, viral, or metagenomic data (different paradigms apply).
- You only need raw read statistics or read trimming (use the `read-qc-trimming` skill first; this meta-skill expects **cleaned reads** as input).

## 0. Orchestrator — detect stage, route to the right skill

This meta-skill is a **router**, not a doer. It does not duplicate logic from the sub-skills. Its job is to ask: **"what stage is the user at, and which sub-skill should they invoke next?"**

### 0.1 Locate the run directory

By convention the agent writes handoff files (see §B) to a run directory. Default: the current working directory. Override with `RUN_DIR` env var.

### 0.1b Locate the skill root — reusable database cache

`SKILL_ROOT` is this skill's own directory (the parent of `annotation/`, `assembly/`, `validation/`, `preflight/`, `runners/`) — **not** `RUN_DIR`. It contains `assets/`, the default download target for the large reference databases (Bakta, Kraken2, BUSCO) so a one-time download is reused across every future run, including Nextflow runs. See `assets/README.md`.

```bash
# Resolve once per session; every sub-skill below assumes this is set.
SKILL_ROOT="/absolute/path/to/skills/bacterial-genome-analysis"
```

Each sub-skill's database-lookup order is: explicit env var / flag → an existing DB the user already pointed at → `$SKILL_ROOT/assets/<db>/` (if populated) → else ask the user (see each sub-skill's stop points).

### 0.2 Detect the user's stage

Try to detect automatically **before** asking:

```bash
# Stage detection ladder — first match wins
test -f "$RUN_DIR/annotation-report.md" && STAGE="annotate-qc-done"
test -f "$RUN_DIR/assembly.fasta"        && STAGE="qc"            # polished FASTA exists → run succeeded, time for QC
test -f "$RUN_DIR/diagnosis.md"          && STAGE="review-diagnosis"
test -f "$RUN_DIR/preflight.md"          && STAGE="assembly"      # preflight done → pick assembly path
test -f "$RUN_DIR/cleaned_R1.fastq.gz"   && STAGE="preflight"     # cleaned reads exist → run preflight sub-skill
: "${STAGE:=preflight}"
```

If auto-detection is ambiguous, ask the user one short question (see **SP0** in §0.5):

> Are you starting a new run, or continuing a previous one?
> 
> - new run (no cleaned reads yet)
> - I have cleaned reads already
> - I just assembled and want QC
> - I just ran QC and want annotation
> - Something failed and I need help debugging

### 0.5 Master ask-user stop points

This orchestrator has **one** user-facing stop point (SP0). All other stop points live in the sub-skills (§1 of each sub-skill). The pattern is **Evidence + Recommend + Options**:

> **Evidence**: I observed X (from $RUN_DIR / params.json / tool output).
> **Recommend**: Y (based on the evidence).
> **Confirm or pick one of**: A / B / C.

#### SP0 — Entry-stage ambiguity

| Trigger | Ask |
|---|---|
| Stage detection returns `preflight` AND no `$RUN_DIR/cleaned_*.fastq.gz` exists | "I don't see cleaned reads at `$RUN_DIR/cleaned_*.fastq.gz`. Did you run `read-qc-trimming`? Or do you want to point me at raw reads?" |

**Auto-pick when**: cleaned reads exist OR user just said "run bacterial-genome-analysis" with no other context → default to `preflight` stage.

#### Routing rule

Auto-pick the default when the evidence is unambiguous. Ask only when the agent genuinely cannot decide. The sub-skills list every stop point and the trigger condition explicitly — the agent reads each one and asks only when its trigger fires.

### 0.3 Route to the right sub-skill

| Stage                 | Action                                                                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `preflight`           | Use `read-qc-trimming` (separate skill) to get cleaned reads. Then invoke `preflight/genome-input-preflight`. Writes `$RUN_DIR/preflight.md` + `params.json` with `GO` / `GO-WITH-WARNINGS` / `NO-GO` verdict. |
| `assembly`            | Invoke `assembly/short-read-assembly`, `assembly/long-read-assembly`, or `assembly/hybrid-assembly` based on the platform in `params.json`. Refuses to run without `preflight.md` showing ≥ GO-WITH-WARNINGS. |
| `polishing`           | Invoke `polishing/genome-polishing` (long-read → short-read sequence). Produces `assembly.fasta`.                                                       |
| `qc`                  | Invoke `validation/assembly-qc`. Produces `report.md` (pass / warn / fail verdicts).                                                                    |
| `qc-done`             | Show the user `$RUN_DIR/report.md`. If `report.md` is `FAIL`, recommend `polishing` or `assembly` re-run.                                               |
| `annotation`          | Invoke `annotation/genome-annotation`. Produces `annotation-report.md` if you also want QC.                                                             |
| `annotate-qc-done`    | Show the user `$RUN_DIR/annotation-report.md`. Final summary.                                                                                           |

**Do not skip read QC.** Even if the user says they have "raw reads", point them at the `read-qc-trimming` skill first. The 4-phase pipeline here assumes cleaned reads upstream; garbage in → garbage out.

**Do not skip preflight.** The preflight sub-skill computes evidence (coverage, contamination, resource availability) and writes a `params.json` that the assembly sub-skills consume. Skipping preflight means the agent has to invent parameters from scratch every time — and the assembly sub-skill will refuse to run without `preflight.md` ≥ GO-WITH-WARNINGS.

### 0.4 The run command (only fires at the `polishing` / `qc` / `annotation` stages)

This skill ships **bash recipes** for each phase — and now also a thin **Nextflow DSL2 runner** as an opt-in sub-skill for production / HPC / cohort runs. The orchestrator decides which path to take:

| Path | When | Cost | Where |
|------|------|------|-------|
| **Bash** (default) | Single-machine dev iteration, 1 isolate | None beyond standard tools | Each sub-skill's `Procedure` section |
| **Nextflow** (v5.1, opt-in) | Production, HPC/cloud, cohort (≥3 isolates), audit trail needed | Requires Nextflow ≥ 23.10 + container runtime | `runners/nextflow-runner/` (this skill) |

For each phase, every sub-skill documents the exact `pixi run` commands. The orchestrator's job is just to:

1. Confirm the upstream artifact exists (`assembly/*.fasta` for polishing; polished FASTA for qc; polished FASTA for annotation).
2. Print the recommended command and ask for confirmation.
3. After execution, write the relevant `report.md` and hand off to the next stage.

For the Nextflow runner — see [`runners/nextflow-runner/SKILL.md`](https://github.com/cheahhl814/bacterial-genome-analysis/tree/master/runners/nextflow-runner). The runner mirrors nf-core/bacass and the [`nextflow-pipelines`](https://github.com/cheahhl814/nextflow-pipelines) style guide.

## A. Pipeline Architecture

The analysis is divided into **five sequential phases**, building upon upstream read quality control and trimming. The agent MUST complete each phase in order and pass the associated "Go/No-Go" gate.

### Phase 0: Preflight (The Audit)

**Goal**: Validate inputs (cleaned reads), compute evidence, and write `params.json` + `preflight.md`. This is the **gating** phase — assembly sub-skills refuse to run without `preflight.md` showing ≥ `GO-WITH-WARNINGS`.

- **Skill**: `preflight/genome-input-preflight`
- **Evidence collected**:
  - Read statistics (`seqkit stats`).
  - Platform auto-detection (mean read length → Illumina / ONT / PacBio-HiFi).
  - Coverage estimate (downsampled `minimap2` + `samtools depth`).
  - Read-level contamination screen (`kraken2` on a subset).
  - Disk space check.
  - Tool availability (with the `setuptools<81` CheckM trap verification).
  - Resource assessment (`nproc`, `free -g`).
- **Must-Verify**: All tools present; coverage sufficient; no major contamination.
- **Exit Gate**: `$RUN_DIR/preflight.md` exists with overall verdict `GO` or `GO-WITH-WARNINGS`; `$RUN_DIR/params.json` exists.

### Phase 1: Assembly (The Draft)

**Goal**: Generate the initial contig set from cleaned reads.

- **Path Selection**:
  - **Short-Read Only**: $\rightarrow$ `assembly/short-read-assembly`
  - **Long-Read Only**: $\rightarrow$ `assembly/long-read-assembly`
  - **Hybrid (S+L)**: $\rightarrow$ `assembly/hybrid-assembly`
- **Must-Verify**: Correct assembler selection based on read length and technology.
- **Exit Gate**: A draft assembly (`.fasta`) exists.

### Phase 2: Polishing (The Correction)

**Goal**: Correct base-level errors (especially INDELs) to achieve "perfect" accuracy.

- **Skill**: `polishing/genome-polishing`
- **Sequential Logic**:
  1. **Long-read polishing** (`Medaka` / `NanoPolish`) $\rightarrow$ Coarse correction.
  2. **Short-read polishing** (`Pypolish` / `Pypolca`) $\rightarrow$ Fine correction.
- **Must-Verify**: Polishing is applied in the correct order (Long $\rightarrow$ Short).
- **Exit Gate**: A polished assembly (`.fasta`) exists.

### Phase 3: Validation (The Quality Gate)

**Goal**: Quantify contiguity, completeness, and contamination.

- **Skill**: `validation/assembly-qc`
- **Critical Tools**:
  - `QUAST` (Contiguity).
  - `CheckM` (Completeness/Contamination).
  - `BUSCO` (Evolutionary completeness).
  - `Kraken2` (Taxonomic contamination).
- **Go/No-Go Criteria**:
  - **Completeness**: $> 95\%$ (MIMAG high-quality standard).
  - **Contamination**: $< 5\%$.
- **Action**: If criteria are not met, the agent must return to Phase 1 or 2 to optimize assembly/polishing.
- **Output**: `report.md` with pass / warn / fail verdicts.

### Phase 4: Annotation (The Labeling)

**Goal**: Identify and label biological features.

- **Skill**: `annotation/genome-annotation`
- **Tool Selection**:
  - **Standard**: `Bakta` (Recommended for 2024/25).
  - **Legacy/Fast**: `Prokka`.
  - **Specialized**: `DFAST`.
  - **Official**: `PGAP` (NCBI).
- **Exit Gate**: Standard output files (`.gff`, `.gbk`, `.faa`) produced.

## B. The Evidence Chain & Handoff Contract

The agent shall maintain a "Genomic State" log and pass explicit artifacts between sub-skills. **The boundary between sub-skills is the filesystem**, not the agent's memory.

| From → To                          | Artifact                                                        | Owner                               | Consumer                       |
| ---------------------------------- | --------------------------------------------------------------- | ----------------------------------- | ------------------------------ |
| `read-qc-trimming` → Preflight     | Cleaned `R1.fastq.gz` (+ `R2.fastq.gz` or `long.fastq.gz`)      | `read-qc-trimming` (external skill) | `preflight/genome-input-preflight` |
| Preflight → Assembly               | `preflight.md` + `params.json` (≥ GO-WITH-WARNINGS verdict)     | `preflight/genome-input-preflight`  | `assembly/*`                   |
| Assembly → Polishing               | `draft.fasta` + cleaned reads (for back-mapping)                | `assembly/*`                        | `polishing/genome-polishing`   |
| Polishing → Validation             | `assembly.fasta`                                                | `polishing/genome-polishing`        | `validation/assembly-qc`       |
| Validation → Annotation            | `assembly.fasta` + `report.md` (≥ PASS-WITH-WARNINGS verdict)   | `validation/assembly-qc`            | `annotation/genome-annotation` |
| Validation → User                  | `report.md` (verdict summary, evidence, reproducibility footer) | `validation/assembly-qc`            | User                           |
| Annotation → User             | `.gff`, `.gbk`, `.faa` + optional `annotation-report.md`        | `annotation/genome-annotation`      | User                           |

Every sub-skill has an **Inputs/Outputs contract** at its top (mirrors `bettamt-*-qc` style). If the upstream artifact is missing, the sub-skill **must refuse to proceed** and tell the user which upstream skill to run.

## C. Output contract — no artifact

This orchestrator skill produces **no file of its own**. Its only outputs are:

- The phase-selection routing decision (§0.3)
- The recommended `pixi run` command for the chosen sub-skill
- The hand-off message naming the next skill

All artifacts (`draft.fasta`, `assembly.fasta`, `report.md`, `.gff`) are produced by the sub-skills. Don't try to write them from here.

## D. Go/No-Go Gates

The agent must stop and warn the user if:

- **Low Completeness**: CheckM completeness is $< 90\%$.
- **High Contamination**: CheckM contamination is $> 10\%$, or Kraken2 detects multiple species.
- **Fragmented Assembly**: N50 is unexpectedly low for a bacterial isolate.
- **Polishing Missed**: Moving to validation without polishing a long-read assembly.

**Note on the two threshold tiers:** the 90%/10% figures above are an early-warning tier — cross this and the agent should flag concern and consider re-optimizing before proceeding. The stricter MIMAG high-quality target used by `validation/assembly-qc` (Phase 3's actual exit gate) is **>95% completeness / <5% contamination**; that stricter pair is what determines the real Go/No-Go decision for annotation. Do not treat "above 90/below 10 but below 95/above 5" as a pass — it is warning territory, not a go.

## E. Common follow-ups

| User says                               | What to do                                                                                                                                                         |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| "Show me my last report"                | `cat $RUN_DIR/report.md`                                                                                                                                           |
| "Did the assembly work?"                | Read `$RUN_DIR/report.md` verdict summary. If missing, run `validation/assembly-qc`.                                                                               |
| "Can I publish this?"                   | Point them to `$RUN_DIR/preflight.md` (input audit), `$RUN_DIR/report.md` (assembly QC), and `$RUN_DIR/annotation-report.md` (annotation QC) as audit-trail artifacts suitable for supplementary material. |
| "I want to run more samples"            | Recommend making a new `$RUN_DIR` per sample. Don't reuse `preflight.md` / `report.md` paths.                                                                       |
| "Annotate my genome"                    | Confirm `report.md` is `PASS`. Then invoke `annotation/genome-annotation`.                                                                                         |
| "Something failed and I don't know why" | Check `preflight/genome-input-preflight`'s **§Signature library** (input validation) and `validation/assembly-qc`'s **§Signature library** (post-assembly). Most common failures are listed there. |
| "What params should I use?"             | Invoke `preflight/genome-input-preflight` — it computes coverage, platform, and resource budget and writes `params.json` with rationale.                           |
| "Screen my isolate for AMR genes"       | AMR screening has moved to its own skill: [`amr-gene-screening`](https://github.com/cheahhl814/amr-gene-screening). Run it after this skill's Phase 4 (annotation). |
| "What AMR genes does my isolate carry?" | Same — use [`amr-gene-screening`](https://github.com/cheahhl814/amr-gene-screening). Default tools: AMRFinderPlus + ABRicate cross-validation. |
| "I need virulence / mobilome / typing / pangenome" | Future separate skills; not yet shipped. See `obs-2026-08-13-recommended-phase-5-extension-for-bacterial-genome-analysis-` for the roadmap. |

## F. Procedural Guidelines

### 1. The Evidence Chain (5 states)

- **State 0**: Cleaned reads $\rightarrow$ Preflight evidence $\rightarrow$ `preflight.md` + `params.json`.
- **State 1**: Preflight passed $\rightarrow$ Draft Assembly.
- **State 2**: Draft Assembly $\rightarrow$ Polished Assembly.
- **State 3**: Polished Assembly $\rightarrow$ QC Metrics (CheckM/QUAST/Kraken2/BUSCO).
- **State 4**: QC Passed $\rightarrow$ Annotated Genome.

### 2. Disk space budget

Bacterial genome assembly is small relative to eukaryotic WGS, but intermediates can still consume 20–50 GB on a high-coverage Illumina run. Before starting, check:

```bash
df -BG "$RUN_DIR" | awk 'NR==2 {print "Free space:", $4, "GB (recommend > 50 GB for typical isolate, > 200 GB for high-coverage Illumina)"}'
```

If free space < 50 GB, warn — `work/` and `results/` coexist during the run.

### 3. Environment detection

```bash
# Are we in a pixi env already?
if command -v pixi >/dev/null 2>&1 && [ -f "$RUN_DIR/pixi.toml" ]; then
    PIXI_ACTIVE=true
    echo "pixi environment available — use 'pixi run <task>' for each phase"
fi
```

## Installation & Environment

This meta-skill assumes a Conda-based environment using `pixi` or `conda`. All tools are available on the `conda-forge` and `bioconda` channels.

```bash
# Initialize a pixi project (run once)
pixi init bacterial-genome-analysis-env
cd bacterial-genome-analysis-env

# Add the required channels
pixi project channel add conda-forge
pixi project channel add bioconda

# Install all tools from the skill's pixi.toml
pixi add --manifest-path /path/to/bacterial-genome-analysis/pixi.toml
```

## Glossary

For users unfamiliar with the terminology:

- **Assembly**: Reconstructing a genome from short/long sequencing reads without a reference.
- **BAM**: Binary Alignment Map (compressed binary format for aligned reads).
- **Basecaller**: Software that converts raw signal data (e.g., ONT Fast5) into nucleotide sequences.
- **BUSCO**: Benchmarking Universal Single-Copy Orthologs (measures genome completeness).
- **CheckM**: Tool for assessing genome completeness and contamination using lineage-specific markers.
- **Contig**: A contiguous stretch of assembled DNA sequence.
- **Coverage (Depth)**: The average number of times each base in the genome is represented by a read. Formula: $\text{Coverage} = \frac{N \times L}{G}$, where $N$ is read count, $L$ is read length, and $G$ is genome size.
- **De Bruijn Graph**: A graph-based data structure used by short-read assemblers (e.g., SPAdes). Nodes are k-mers, edges represent k-1 overlaps.
- **Hybrid Assembly**: Combining short and long reads to leverage the accuracy of short reads and the structural resolution of long reads.
- **INDEL**: Insertion or deletion of bases in the genome relative to the reference.
- **Kraken2**: Taxonomic classification system that assigns reads to taxonomic groups using exact k-mer matches.
- **Long-Read Sequencing**: Sequencing technologies that produce reads $>10,000$ bp (ONT, PacBio).
- **MIMAG**: Minimum Information about a Metagenome-Assembled Genome (or isolate genome) standard.
- **N50**: A contiguity metric; 50% of the assembly is contained in contigs of length N50 or longer.
- **ONT**: Oxford Nanopore Technologies (a long-read sequencing platform).
- **PacBio**: Pacific Biosciences (a long-read sequencing platform).
- **Polishing**: Correcting base-level errors in a draft assembly using aligned reads.
- **QUAST**: Quality Assessment Tool for Genome Assemblies.
- **Read**: A single sequence fragment generated by a sequencing instrument.
- **Reference Genome**: A previously assembled, high-quality genome used for comparison.
- **Short-Read Sequencing**: Sequencing technologies producing reads of $100\text{-}300$ bp (e.g., Illumina).
- **sORF**: Small Open Reading Frame (often missed by older annotation tools but captured by Bakta).
- **Taxon / Taxonomy**: The hierarchical classification of an organism (species, genus, family, etc.).

## Verification

- [ ] Read QC was performed upstream (`read-qc-trimming` skill).
- [ ] Preflight was performed (`preflight/genome-input-preflight`); `preflight.md` overall verdict ≥ `GO-WITH-WARNINGS`.
- [ ] All four phases (Assembly → Polishing → Validation → Annotation) completed in sequence.
- [ ] Polishing sequence followed: Long $\rightarrow$ Short.
- [ ] CheckM completeness $> 95\%$ and contamination $< 5\%$.
- [ ] `report.md` produced by `validation/assembly-qc` shows PASS verdict.
- [ ] Kraken2 confirms sample purity.
- [ ] Final annotation produced in GFF and GenBank formats.

## Handoff pointers

After this orchestrator routes the user to a phase, the agent should explicitly state which sub-skill was invoked and what file it produces. Example:

> I've handed off to `validation/assembly-qc`. It will run CheckM, QUAST, BUSCO, and Kraken2 against your polished FASTA, then write `report.md` to your run directory with pass/warn/fail verdicts. Say the word and I'll invoke it.
