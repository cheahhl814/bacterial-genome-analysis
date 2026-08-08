---
name: genome-polishing
description: Correct base-level errors in bacterial genome assemblies. This skill implements a multi-stage polishing sequence: long-read polishing (Medaka/NanoPolish) followed by short-read polishing (Pypolish/Pypolca) to achieve "perfect" nucleotide accuracy.
version: 2
updated: "2026-08-09"
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

## Description

Genome polishing is the process of correcting errors (primarily INDELs and SNPs) in a draft assembly. This skill is mandatory for long-read and hybrid assemblies to reach "perfect" accuracy. It follows a strict sequence: **Long-read polishing $\rightarrow$ Short-read polishing**.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: 
  - A draft assembly (`.fasta`) from `skills/bacterial-genome-analysis/assembly/`.
  - Long reads (`.fastq.gz`) for long-read polishing.
  - Short reads (`.fastq.gz`) for short-read polishing (mandatory for hybrid/high-quality workflows).
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
minimap2 -ax map-ont -t 8 assembly.fasta long_reads.fastq.gz | \
  samtools sort -o mapped.bam -
samtools index mapped.bam

# 2. Run Medaka
medaka_consensus -i long_reads.fastq.gz \
                 -d assembly.fasta \
                 -o medaka_output/ \
                 -t 8
# Result: medaka_output/consensus.fasta
```

#### Path B: NanoPolish (Requires Fast5)
NanoPolish is an older tool requiring signal-level data (Fast5).
```bash
nanopolish index -d fast5_dir/ long_reads.fastq.gz
bwa-mem2 -x ont2d assembly.fasta long_reads.fastq.gz | samtools sort -o mapped.bam -
samtools index mapped.bam
nanopolish variants --consensus polished.fasta -p 8 -b mapped.bam -g assembly.fasta
```

### 2. Stage 2: Short-Read Polishing (Fine)

Short reads have much higher base-level accuracy and are used to "clean up" the remaining errors.

#### Path A: Pypolish (Iterative, Recommended)
Pypolish iteratively aligns short reads and corrects the consensus.
```bash
# 1. Index the assembly
bwa-mem2 index assembly.fasta

# 2. Map reads
bwa-mem2 -t 8 assembly.fasta R1.fq.gz R2.fq.gz | \
  samtools sort -o mapped.bam -
samtools index mapped.bam

# 3. Run Pypolish
polypolish filter --in mapped.bam --out filtered.bam
polypolish polish --assembly assembly.fasta --in filtered.bam --out polished.fasta
```

#### Path B: Pypolca (Single-Pass)
Use `Pypolca-careful` to avoid over-correcting real biological variation.
```bash
bwa-mem2 index assembly.fasta
bwa-mem2 -t 8 assembly.fasta R1.fq.gz R2.fq.gz | \
  samtools sort -o mapped.bam -
samtools index mapped.bam
pypolca run -a assembly.fasta -o polished.fasta -r -t 8 mapped.bam
```

## Interpretation Guidelines

- **Error Reduction**: Compare the number of INDELs before and after polishing by mapping reads back and checking mismatch rates.
- **Base-level Accuracy**: Polishing should move the assembly from $\approx 95\text{-}99\%$ accuracy to $> 99.99\%$.
- **Over-polishing**: Be cautious of removing rare variants. Use Pypolca's `careful` mode or verify against the raw read mapping.

## Verification

- [ ] Polishing sequence followed: Long-read $\rightarrow$ Short-read.
- [ ] `final_polished.fasta` exists.
- [ ] For short-read polishing, a minimum coverage (usually $> 20\times$) was verified.