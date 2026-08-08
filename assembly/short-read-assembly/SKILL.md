---
name: short-read-assembly
description: Assemble bacterial genomes from short-read sequencing data (e.g., Illumina). This skill focuses on producing the most contiguous draft possible from paired-end reads, typically utilizing De Bruijn graph assemblers.
version: 1
updated: "2026-08-09"
triggers:
  - "assemble short reads"
  - "illumina assembly"
  - "SPAdes"
  - "SKESA"
  - "bacterial assembly short-read"
---

# Skill: short-read-assembly

## Description

Assemble bacterial genomes from short-read sequencing data. Since short reads cannot resolve large repeats, the result is typically a fragmented draft (multiple contigs). This skill transforms cleaned FASTQ files into a FASTA assembly.

## Prerequisites

- **Environment**: Active Pixi environment.
- **Upstream Evidence**: Cleaned reads (`.fastq.gz`) from `skills/read-trimming-cleaning/SKILL.md`.

## Installation

```bash
pixi add spades skesa
```

## Procedure

### 1. Tool Selection

| Data Quality | Recommended Tool | Reason |
| :--- | :--- | :--- |
| **Standard** | `SPAdes` | Best-in-class for small genomes; high contiguity. |
| **High-Throughput / Fast** | `SKESA` | Faster and more memory-efficient; avoids some SPAdes artifacts. |

### 2. Execution

#### Path A: SPAdes (Standard)
```bash
spades.py --careful -t 8 -1 R1.fq.gz -2 R2.fq.gz -o spades_output/
# Final assembly is spades_output/scaffolds.fasta
```

#### Path B: SKESA (Fast)
```bash
skesa --reads R1.fq.gz R2.fq.gz --output assembly.fasta
```

## Interpretation Guidelines

- **Contiguity**: Check the number of contigs. A high number of contigs is expected for short-read only assemblies.
- **N50**: Use as a rough proxy for assembly quality (higher is better).

## Verification

- [ ] `scaffolds.fasta` or `assembly.fasta` exists.
- [ ] The total assembly length is approximately equal to the expected genome size of the species.
