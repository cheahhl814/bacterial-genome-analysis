---
name: short-read-assembly
description: Assemble bacterial genomes from short-read sequencing data (Illumina). This skill focuses on producing the most contiguous draft possible from paired-end reads, utilizing De Bruijn graph assemblers and integrating quality control to ensure data integrity before assembly.
version: 3
updated: "2026-08-09"
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

## Description

Assemble bacterial genomes from short-read sequencing data. Since short reads cannot resolve large repetitive regions (e.g., rRNA operons, mobile elements), the result is typically a fragmented draft. This skill transforms cleaned FASTQ files into a FASTA assembly following the **nf-core/bacass** paradigm.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: Cleaned reads (`.fastq.gz`) produced by the `read-qc-trimming` skill.

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add spades skesa megahit kraken2
```

## Procedure

### 1. Strategy Selection

| Data Type / Goal | Recommended Tool | Reason |
| :--- | :--- | :--- |
| **Standard (High Contiguity)** | `SPAdes` | Best-in-class for small genomes; uses multi-size De Bruijn graphs. |
| **High-Throughput / Fast** | `SKESA` | Faster and more memory-efficient; avoids some SPAdes artifacts. |
| **Metagenomes / Large Inputs** | `MEGAHIT` | Optimized for large, potentially complex datasets (used in nf-core/bacass for short reads). |
| **Hybrid (requires long reads)** | `Unicycler` (Short-read mode) | Optimizes SPAdes k-mers and bridges contigs (refer to hybrid-assembly skill). |

### 2. Execution

#### Path A: SPAdes (Standard)
SPAdes uses a multi-k-mer approach to resolve complex genomic regions.

```bash
spades.py --careful \
          -t 8 \
          -1 R1.fq.gz -2 R2.fq.gz \
          -o spades_output/
# Final assembly: spades_output/scaffolds.fasta
```
*Note: The `--careful` flag reduces misassemblies by performing mismatch correction.*

#### Path B: SKESA (Fast)
```bash
skesa --reads R1.fq.gz R2.fq.gz --cores 8 --output assembly.fasta
```

#### Path C: MEGAHIT (Large/Complex)
```bash
megahit -1 R1.fq.gz -2 R2.fq.gz -o megahit_output/ -t 8
# Final assembly: megahit_output/final.contigs.fa
```

### 3. Contamination Verification (The Gate)
Before proceeding to polishing (if applicable) or annotation, the assembly MUST be checked for contamination.

```bash
kraken2 --db /path/to/kraken2_db --threads 8 \
        --output kraken2.report --report kraken2_summary.txt \
        --confidence 0.05 \
        spades_output/scaffolds.fasta
```
- **Acceptance Criteria**: $>95\%$ of contigs must align to the expected genus.

## Interpretation Guidelines

- **Contiguity**: Check the number of contigs. A high number of contigs is expected for short-read only assemblies.
- **N50**: Use as a rough proxy for assembly quality (higher is better).
- **Misassemblies**: SPAdes `--careful` mitigates this; check QUAST for misassembly metrics.

## Verification

- [ ] `scaffolds.fasta` or `assembly.fasta` exists.
- [ ] The total assembly length is approximately equal to the expected genome size of the species.
- [ ] `Kraken2` report confirms the sample matches the expected organism.