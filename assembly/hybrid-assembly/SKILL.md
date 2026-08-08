---
name: hybrid-assembly
description: Combine short and long reads to assemble high-fidelity, complete bacterial genomes. This skill implements a long-read-first strategy to resolve repeats, followed by short-read polishing for base-level accuracy.
version: 1
updated: "2026-08-09"
triggers:
  - "hybrid assembly"
  - "combine short and long reads"
  - "Unicycler"
  - "Hybracter"
  - "complete bacterial genome"
---

# Skill: hybrid-assembly

## Description

Assemble bacterial genomes using both short (Illumina) and long (ONT/PacBio) reads. This is the gold standard for producing "closed" genomes where chromosomes and plasmids are fully resolved without gaps.

## Prerequisites

- **Environment**: Active Pixi environment.
- **Upstream Evidence**: 
  - Cleaned short reads (`.fastq.gz`).
  - Cleaned long reads (`.fastq.gz`).

## Installation

```bash
pixi add hybracter unicycler
```

## Procedure

### 1. Strategy Selection

| Goal | Recommended Tool | Strategy |
| :--- | :--- | :--- |
| **High-Throughput/Automated** | `Hybracter` | Long-read first $\rightarrow$ Short-read polishing. Scalable and modern. |
| **Standard / Manual Control** | `Unicycler` | Uses SPAdes for short reads and merges with long reads. |

### 2. Execution

#### Path A: Hybracter (Recommended)
Hybracter implements a modern, long-read-first approach that scales better than older hybrid tools.

```bash
# Hybracter typically runs via a config or samplesheet
hybracter --long reads_long.fq.gz --short R1.fq.gz R2.fq.gz --out output_dir/
```

#### Path B: Unicycler
```bash
unicycler -1 R1.fq.gz -2 R2.fq.gz -l reads_long.fq.gz -o unicycler_output/
```

## Interpretation Guidelines

- **Closure**: Check for circular contigs.
- **Consistency**: Ensure the total genome size matches the expected size for the organism.

## Verification

- [ ] `assembly.fasta` exists.
- [ ] The assembly is validated for circularity where applicable.
- [ ] Total assembly length matches the target species size.
