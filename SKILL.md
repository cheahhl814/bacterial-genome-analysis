---
name: bacterial-genome-analysis
description: End-to-end orchestration of bacterial genome reconstruction, from raw reads to a fully annotated, high-fidelity genomic sequence. This meta-skill integrates QC, assembly, polishing, validation, and annotation into a strict evidence chain based on the nf-core/bacass paradigm.
version: 4
updated: "2026-08-09"
triggers:
  - "assemble bacterial genome"
  - "complete bacterial assembly"
  - "bacterial genome pipeline"
  - "de novo bacterial assembly"
  - "annotate bacterial genome"
  - "hybrid bacterial assembly"
---

# Meta-Skill: bacterial-genome-analysis

## Audience

This meta-skill is designed to serve **two simultaneous audiences**:

1.  **AI Coding Agents**: Triggered by the phrases above. The agent must execute the strict evidence chain and Go/No-Go gates described below.
2.  **Human Users (Bioinformaticians & Biologists)**: Read this document as a workflow guide. The sections explain *why* each phase exists and *what* trade-offs apply at each decision point.

## When to Use This Skill

Use this meta-skill when you need to:
-   Reconstruct a bacterial genome **de novo** (without a reference genome).
-   Achieve a **complete, closed** genome (single contig per replicon).
-   Compare genomes or study population genetics (requires high-quality assemblies).
-   Submit a genome to a public repository like NCBI (requires annotation).
-   Identify antimicrobial resistance (AMR) genes, virulence factors, or metabolic pathways.

**Do NOT use this skill** if:
-   You have a well-characterized reference genome (use a reference-based variant calling pipeline instead).
-   You are analyzing eukaryotic, viral, or metagenomic data (different paradigms apply).
-   You only need raw read statistics (use a read QC skill instead).

## Description

This meta-skill orchestrates the full bacterial genome reconstruction pipeline. It ensures that the assembly is not just a "draft" but is polished for nucleotide accuracy and validated for completeness and contamination before functional annotation. The workflow follows the best practices implemented in `nf-core/bacass`.

## Pipeline Architecture

The analysis is divided into four sequential phases, building upon upstream read quality control and trimming. The agent MUST complete each phase in order and pass the associated "Go/No-Go" gate.

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

### Phase 4: Annotation (The Labeling)
**Goal**: Identify and label biological features.
- **Skill**: `annotation/genome-annotation`
- **Tool Selection**:
  - **Standard**: `Bakta` (Recommended for 2024/25).
  - **Legacy/Fast**: `Prokka`.
  - **Specialized**: `DFAST`.
  - **Official**: `PGAP` (NCBI).
- **Exit Gate**: Standard output files (`.gff`, `.gbk`, `.faa`) produced.

## Procedural Guidelines

### 1. The Evidence Chain
The agent shall maintain a "Genomic State" log:
- **State 1**: Cleaned reads $\rightarrow$ Draft Assembly.
- **State 2**: Draft Assembly $\rightarrow$ Polished Assembly.
- **State 3**: Polished Assembly $\rightarrow$ QC Metrics (CheckM/QUAST/Kraken2).
- **State 4**: QC Passed $\rightarrow$ Annotated Genome.

### 2. Go/No-Go Gates
The agent must stop and warn the user if:
- **Low Completeness**: CheckM completeness is $< 90\%$.
- **High Contamination**: CheckM contamination is $> 10\%$, or Kraken2 detects multiple species.
- **Fragmented Assembly**: N50 is unexpectedly low for a bacterial isolate.
- **Polishing Missed**: Moving to validation without polishing a long-read assembly.

## Installation & Environment

This meta-skill assumes a Conda-based environment using `pixi` or `conda`. All tools are available on the `conda-forge` and `bioconda` channels.

```bash
# Initialize a pixi project (run once)
pixi init bacterial-genome-analysis-env
cd bacterial-genome-analysis-env

# Add the required channels
pixi project channel add conda-forge
pixi project channel add bioconda
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

- [ ] All four phases completed in sequence.
- [ ] Polishing sequence followed: Long $\rightarrow$ Short.
- [ ] CheckM completeness $> 95\%$ and contamination $< 5\%$.
- [ ] Kraken2 confirms sample purity.
- [ ] Final annotation produced in GFF and GenBank formats.