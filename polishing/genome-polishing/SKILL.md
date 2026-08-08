---
name: genome-polishing
description: Correct base-level errors in bacterial genome assemblies. This skill implements a two-stage polishing sequence: long-read polishing for structural consensus and short-read polishing for high-fidelity nucleotide accuracy.
version: 1
updated: "2026-08-09"
triggers:
  - "polish genome"
  - "correct assembly errors"
  - "Medaka"
  - "Dorado polish"
  - "Pypolish"
  - "Pypolca"
  - "polish ONT assembly"
---

# Skill: genome-polishing

## Description

Genome polishing is the process of correcting errors (primarily INDELs and SNPs) in a draft assembly. This skill is mandatory for long-read assemblies to reach "perfect" accuracy. It follows a strict sequence: **Long-read polishing $\rightarrow$ Short-read polishing**.

## Prerequisites

- **Environment**: Active Pixi environment.
- **Upstream Evidence**: 
  - A draft assembly (`.fasta`) from `skills/bacterial-genome-analysis/assembly/`.
  - Long reads (`.fastq.gz`) for long-read polishing.
  - Short reads (`.fastq.gz`) for short-read polishing (optional but recommended).

## Installation

```bash
pixi add medaka pypolish pypolca
# Dorado is typically installed via the ONT toolsuite or as a standalone binary
```

## Procedure

### 1. Stage 1: Long-Read Polishing (Coarse)

This step uses the same long reads used for assembly to correct large-scale errors and improve consensus.

#### Path A: Medaka (Standard)
```bash
medaka_consensus -i reads.fastq.gz -d assembly.fasta -o medaka_output/
# Result: medaka_output/consensus.fasta
```

#### Path B: Dorado Polish (Latest 2024/25)
For v5.0.0+ datasets, `dorado polish` is the current high-performance alternative.
```bash
dorado polish assembly.fasta reads.fastq.gz > polished_assembly.fasta
```

### 2. Stage 2: Short-Read Polishing (Fine)

Short reads have much higher base-level accuracy and are used to "clean up" the remaining errors.

#### Path A: Pypolish (General)
```bash
pypolish assembly.fasta R1.fq.gz R2.fq.gz > final_polished.fasta
```

#### Path B: Pypolca (Careful Mode)
Use `Pypolca-careful` to avoid over-correcting real biological variation.
```bash
pypolca -c assembly.fasta R1.fq.gz R2.fq.gz > final_polished.fasta
```

## Interpretation Guidelines

- **Error Reduction**: Compare the number of INDELs before and after polishing (e.g., by mapping reads back and checking mismatch rates).
- **Base-level Accuracy**: Polishing should move the assembly from $\approx 95\text{-}99\%$ accuracy to $> 99.99\%$.

## Verification

- [ ] Polishing sequence followed: Long-read $\rightarrow$ Short-read.
- [ ] `final_polished.fasta` exists.
- [ ] For short-read polishing, a minimum coverage (usually $> 20\times$) was verified.
