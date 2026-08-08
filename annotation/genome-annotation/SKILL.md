---
name: genome-annotation
description: Assign biological functions to the features of a bacterial genome assembly. This skill transforms a validated FASTA assembly into a set of standard annotation files (GFF, GBK, FAA), supporting modern tools like Bakta and DFAST.
version: 2
updated: "2026-08-09"
triggers:
  - "annotate genome"
  - "find genes in assembly"
  - "Bakta"
  - "Prokka"
  - "DFAST"
  - "bacterial annotation"
  - "gene prediction"
---

# Skill: genome-annotation

## Description

Genome annotation identifies protein-coding sequences (CDS), RNAs, and other genomic features, assigning them names and functions based on homology and ab initio prediction. This skill transforms a validated assembly into standard bioinformatics files.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: A validated, polished assembly (`.fasta`) from `skills/bacterial-genome-analysis/validation/`.
- **Required Tools**: 
  - `Bakta` (Modern annotation, recommended).
  - `Prokka` (Legacy fast annotation).
  - `DFAST` (Alternative annotation).
  - `tbl2asn` (For GenBank submission).

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add bakta prokka dfast
# Bakta database download (one-time)
bakta_db download -o /path/to/bakta_db
```

## Procedure

### 1. Tool Selection

| Goal | Recommended Tool | Reason |
| :--- | :--- | :--- |
| **Standard / High Quality** | `Bakta` | Next-gen replacement for Prokka; superior DBs, better sORF handling. |
| **Fast / Legacy** | `Prokka` | Extremely fast; standard output; widely used. |
| **Specialized (DFAST features)** | `DFAST` | Lightweight; good for specific taxonomy; used in nf-core/bacass. |
| **Submission Grade** | `PGAP` | Required for NCBI/GenBank; most authoritative. |

### 2. Execution

#### Path A: Bakta (Recommended)
Bakta uses a comprehensive UniRef-based database for superior functional annotation.

```bash
bakta --db /path/to/bakta_db \
      --threads 8 \
      --output bakta_output/ \
      --prefix sample1 \
      assembly.fasta
```
*Key Outputs:*
- `sample1.gff3`: General Feature Format.
- `sample1.gbff`: GenBank Flat File.
- `sample1.faa`: FASTA Amino Acid (proteins).
- `sample1.fna`: FASTA Nucleotide (CDSs).
- `sample1.json`: Machine-readable annotation.

#### Path B: Prokka
```bash
prokka --outdir prokka_output \
       --prefix sample1 \
       --cpus 8 \
       --genus Escherichia \
       --species coli \
       assembly.fasta
```
*Note: Providing `--genus` and `--species` significantly speeds up Prokka.*

#### Path C: DFAST
```bash
dfast --genome assembly.fasta \
      --output dfast_output \
      --database dfast_db \
      --cpu 8
```

### 3. Output Files

The agent shall ensure the following files are produced:
- **`.gff`/`.gff3`**: General Feature Format (coordinates and types).
- **`.gbk`/`.gbff`**: GenBank format (full annotations including sequence).
- **`.faa`**: FASTA Amino Acid (protein sequences).
- **`.fna`**: FASTA Nucleotide (coding sequences).

## Interpretation Guidelines

- **Gene Density**: Check for gaps in annotation. Unusually large non-coding regions may indicate assembly errors or actual biological features (e.g., large plasmids, prophages).
- **Consistency**: Compare `Bakta` and `Prokka` results for critical genes (e.g., AMR genes) if the biological question is high-stakes.
- **Hypothetical Proteins**: A high percentage is expected, but if $>50\%$ of genes are hypothetical, consider re-annotation with `Bakta` or `PGAP`.

## Verification

- [ ] `.gff` and `.gbk` files exist.
- [ ] Total number of predicted genes is reasonable for the target species (e.g., $\approx 3\text{-}5$ Mbp $\rightarrow$ $3000\text{-}5000$ genes).
- [ ] The annotation is compatible with downstream tools (e.g., Roary, Panaroo).
- [ ] For NCBI submission, `.sqn` file generated via `tbl2asn`.