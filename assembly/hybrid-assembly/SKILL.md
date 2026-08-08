---
name: hybrid-assembly
description: Combine short and long reads to assemble high-fidelity, complete bacterial genomes. This skill implements both Unicycler (short-read first) and Dragonflye (long-read first) strategies to resolve repeats and close gaps.
version: 2
updated: "2026-08-09"
triggers:
  - "hybrid assembly"
  - "combine short and long reads"
  - "Unicycler"
  - "Dragonflye"
  - "complete bacterial genome"
  - "close gaps"
---

# Skill: hybrid-assembly

## Description

Assemble bacterial genomes using both short (Illumina) and long (ONT/PacBio) reads. This is the gold standard for producing "closed" genomes where chromosomes and plasmids are fully resolved without gaps. The `nf-core/bacass` pipeline supports two primary paradigms: Unicycler and Dragonflye.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: 
  - Cleaned short reads (`.fastq.gz`).
  - Cleaned long reads (`.fastq.gz`).
- **Required Tools**:
  - **Short-read QC**: `FastQC`, `FastP`.
  - **Long-read QC**: `NanoPlot`, `Filtlong`.
  - **Assembly**: `Unicycler` (Short-read first), `Dragonflye` (Long-read first).

## Installation

```bash
pixi add unicycler dragonflye spades flye medaka pypolish pypolca
```

## Procedure

### 1. Strategy Selection

| Paradigm | Recommended Tool | Strategy | Pros | Cons |
| :--- | :--- | :--- | :--- | :--- |
| **Short-Read First** | `Unicycler` | SPAdes assembly $\rightarrow$ Scaffold with long reads. | Excellent for low-coverage long reads. | Slower; depends on short-read depth. |
| **Long-Read First** | `Dragonflye` | Flye assembly $\rightarrow$ Polishing with short reads. | Highly accurate; resolves complex repeats. | Requires high-quality long reads. |
| **Automated / Modern** | `Hybracter` | Long-read first $\rightarrow$ Automated polishing. | Scalable; updated for modern tools. | Newer ecosystem. |

### 2. Execution

#### Path A: Unicycler (Short-Read First)
Unicycler is the most widely used hybrid assembler. It builds an SPAdes assembly graph, then bridges contigs using long reads.

```bash
unicycler -1 R1.fq.gz -2 R2.fq.gz \
          -l long_reads.fastq.gz \
          -o unicycler_output/ \
          -t 8
```
*Key Flags:*
- `-l`: Long reads (FastA/FastQ, gzipped supported).
- `--no_miniasm`: Skip the long-read assembly step if coverage is low.

#### Path B: Dragonflye (Long-Read First)
Dragonflye wraps Flye (or other long-read assemblers) and applies short-read polishing.

```bash
dragonflye --reads long_reads.fastq.gz \
           --R1 R1.fq.gz --R2 R2.fq.gz \
           --outdir dragonflye_out/ \
           --assembler flye \
           --polish-rounds 3 \
           --threads 8
```

## Interpretation Guidelines

- **Closure**: Check for circular contigs. Unicycler and Dragonflye both attempt to circularize the genome.
- **Consistency**: Ensure the total genome size matches the expected size for the organism.
- **Plasmids**: Pay special attention to plasmid reconstruction. Unicycler excels at separating plasmids with similar sequences.

## Verification

- [ ] `assembly.fasta` exists in the output directory.
- [ ] The assembly is validated for circularity where applicable (e.g., via Bandage or QUAST).
- [ ] Total assembly length matches the target species size.
- [ ] Plasmids are fully resolved or documented if fragmented.