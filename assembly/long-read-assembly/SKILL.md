---
name: long-read-assembly
description: Assemble bacterial genomes from long-read sequencing data (ONT/PacBio). This skill implements the consensus assembly paradigm to resolve repeats and produce near-complete circular chromosomes and plasmids, integrating quality filtering and depth downsampling.
version: 2
updated: "2026-08-09"
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

## Description

Assemble bacterial genomes from long-read sequencing data. This skill moves beyond simple assembly by implementing a consensus approach (via Autocycler or Dragonflye) to minimize structural errors and maximize contiguity.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: Long reads (`.fastq.gz`).
- **Required Tools**:
  - **QC**: `NanoPlot`, `PycoQC` (Sequencing summary stats).
  - **Trimming/Filtering**: `Filtlong` (Quality filtering), `PoreChop` (Adapter trimming).
  - **Downsampling**: `Rasusa` (Target coverage downsampling).
  - **Assembly**: `Flye`, `Raven`, `Canu`, `Miniasm` + `Racon`.
  - **Consensus**: `Autocycler`, `Dragonflye`.

## Installation

```bash
pixi add nanoplot pycoqc filtlong porechop rasusa \
          flye raven canu miniasm racon autocycler dragonflye
```

## Procedure

### 1. Upstream Quality Control (The Pre-Filter)
Long reads must be filtered before assembly to remove adapters and poor-quality sequences.

#### A. Quality Filtering (Filtlong)
```bash
filtlong --min_length 1000 --keep_percent 95 \
         --target_bases 500000000 \
         input_reads.fastq.gz | gzip > filtered_reads.fastq.gz
```
*Tip: Adjust `--target_bases` to the expected genome size $\times$ coverage.*

#### B. Adapter Trimming (PoreChop)
```bash
porechop -i input_reads.fastq.gz -o trimmed_reads.fastq.gz
```

#### C. QC Reporting
```bash
nanoplot --fastq filtered_reads.fastq.gz --outdir nanoplot_output/ -t 8
```

### 2. Primary Assembly (The Draft)
The agent selects an assembler based on data type and memory constraints.

| Read Type | Recommended Tool | Notes |
| :--- | :--- | :--- |
| **ONT / PacBio (Standard)** | `Flye` | Extremely robust; excellent for plasmids. |
| **ONT (Fast/Low RAM)** | `Raven` | Very fast; low memory footprint. |
| **PacBio (HiFi)** | `Flye --pacbio-hifi` | Highly accurate; uses HiFi reads. |
| **ONT (High Accuracy)** | `Canu` | Legacy gold standard; high memory usage. |
| **Minimal Memory** | `Miniasm` + `Racon` | Sketch-based assembly (requires extensive polishing). |

**Example (Flye):**
```bash
flye --nano-raw filtered_reads.fastq.gz \
     --out-dir flye_output/ \
     --threads 8 \
     --genome-size 3m
# Result: flye_output/assembly.fasta
```

### 3. Consensus Assembly (The Refinement)

To avoid the "single-assembler bias" and structural errors, the agent MUST use a consensus tool.

#### Path A: Autocycler (Standard Paradigm)
`Autocycler` is the successor to Trycycler. It generates multiple assembly attempts and finds the most consistent consensus.

```bash
# Subsample reads (Autocycler requires multiple subsets)
autocycler subsample --reads filtered_reads.fastq.gz --out_dir autocycler_out/

# Run multiple primary assemblies (e.g., Flye, Raven, Miniasm+Racon)
# Then combine into a consensus:
autocycler combine --assemblies all_assemblies/*.fasta --out_dir combined_out/
autocycler resolve --inputs combined_out/ --out_dir resolved_out/
```
*Final Result:* `resolved_out/consensus.fasta`

#### Path B: Dragonflye (Automated Wrappers)
`Dragonflye` is an automated wrapper for long-read assembly using Flye + Medaka + Polypolish/Pypolca.
```bash
dragonflye --reads filtered_reads.fastq.gz --outdir dragonflye_out/ \
           --assembler flye --polish-rounds 3
```

## Interpretation Guidelines

- **Circularization**: Check if the assembly reports circular chromosomes or plasmids. This is the goal for bacterial genomes.
- **Contig Count**: A "perfect" assembly has one contig per replicon (chromosome + plasmids).
- **N50**: For a single circular chromosome, the N50 will be approximately the genome size.

## Verification

- [ ] Filtered reads (e.g., Filtlong) exist.
- [ ] Primary assembly (Flye/Raven) exists.
- [ ] Consensus assembly (`Autocycler` or `Dragonflye`) exists.
- [ ] The agent has verified that circularization was attempted.