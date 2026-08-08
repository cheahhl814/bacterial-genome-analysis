---
name: genome-annotation
description: Assign biological functions to the features of a bacterial genome assembly. This skill transforms a validated FASTA assembly into a set of standard annotation files (GFF, GBK, FAA).
version: 1
updated: "2026-08-09"
triggers:
  - "annotate genome"
  - "find genes in assembly"
  - "Bakta"
  - "Prokka"
  - "PGAP"
  - "bacterial annotation"
---

# Skill: genome-annotation

## Description

Genome annotation identifies protein-coding sequences (CDS), RNAs, and other genomic features, assigning them names and functions based on homology and ab initio prediction. This skill transforms a validated assembly into standard bioinformatics files.

## Prerequisites

- **Environment**: Active Pixi environment.
- **Upstream Evidence**: A validated, polished assembly (`.fasta`) from `skills/bacterial-genome-analysis/validation/`.

## Installation

```bash
pixi add bakta prokka
# PGAP is typically run via a standalone container or NCBI cloud pipeline
```

## Procedure

### 1. Tool Selection

| Goal | Recommended Tool | Reason |
| :--- | :--- | :--- |
| **Standard / High Quality** | `Bakta` | Next-gen replacement for Prokka; superior DBs, better sORF handling. |
| **Fast / Legacy** | `Prokka` | Extremely fast; standard output; widely used. |
| **Submission Grade** | `PGAP` | Required for NCBI/GenBank; most authoritative. |

### 2. Execution

#### Path A: Bakta (Recommended)
```bash
bakta --db /path/to/bakta_db assembly.fasta --output bakta_output/ --prefix sample1
```

#### Path B: Prokka
```bash
prokka --outdir prokka_output --prefix sample1 assembly.fasta
```

### 3. Output Files

The agent shall ensure the following files are produced:
- **`.gff`**: General Feature Format (coordinates and types).
- **`.gbk`**: GenBank format (full annotations including sequence).
- **`.faa`**: FASTA Amino Acid (protein sequences).
- **`.fna`**: FASTA Nucleotide (coding sequences).

## Interpretation Guidelines

- **Gene Density**: Check for gaps in annotation. Unusually large non-coding regions may indicate assembly errors or actual biological features.
- **Consistency**: Compare `Bakta` and `Prokka` results for critical genes (e.g., AMR genes) if the biological question is high-stakes.

## Verification

- [ ] `.gff` and `.gbk` files exist.
- [ ] Total number of predicted genes is reasonable for the target species (e.g., $\approx 3\text{-}5$ Mbp $\rightarrow$ $3000\text{-}5000$ genes).
- [ ] The annotation is compatible with downstream tools (e.g., Roary, Panaroo).
