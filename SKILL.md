---
name: bacterial-genome-analysis
description: End-to-end orchestration of bacterial genome reconstruction. This meta-skill transforms raw sequencing reads into a validated, annotated, and high-fidelity genomic sequence, managing the transition from draft assembly to polished "finished" genome.
version: 1
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

## Description

This meta-skill orchestrates the full bacterial genome reconstruction pipeline. It ensures that the assembly is not just a "draft" but is polished for nucleotide accuracy and validated for completeness and contamination before functional annotation.

## Pipeline Architecture

The analysis is divided into four sequential phases. The agent MUST complete each phase in order and pass the associated "Go/No-Go" gate.

### Phase 1: Assembly (The Draft)

**Goal**: Generate the initial contig set from raw reads.

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
  1. **Long-read polishing** (e.g., Medaka/Dorado) $\rightarrow$ Coarse correction.
  2. **Short-read polishing** (e.g., Pypolish/Pypolca) $\rightarrow$ Fine correction.
- **Must-Verify**: Polishing is applied in the correct order (Long $\rightarrow$ Short).
- **Exit Gate**: A polished assembly (`.fasta`) exists.

### Phase 3: Validation (The Quality Gate)

**Goal**: Quantify contiguity, completeness, and contamination.

- **Skill**: `validation/assembly-qc`
- **Critical Tools**: `QUAST` (Contiguity), `CheckM` (Completeness/Contamination), `BUSCO` (Evolutionary completeness).
- **Go/No-Go Criteria**:
  - **Completeness**: $> 95\%$.
  - **Contamination**: $< 5\%$.
- **Action**: If criteria are not met, the agent must return to Phase 1 or 2 to optimize assembly/polishing.

### Phase 4: Annotation (The Labeling)

**Goal**: Identify and label biological features.

- **Skill**: `annotation/genome-annotation`
- **Tool Selection**:
  - **Standard**: `Bakta` (Recommended for 2024/25).
  - **Legacy**: `Prokka`.
  - **Official**: `PGAP` (NCBI).
- **Exit Gate**: Standard output files (`.gff`, `.gbk`, `.faa`) produced.

## Procedural Guidelines

### 1. The Evidence Chain

The agent shall maintain a "Genomic State" log:

- **State 1**: `reads` $\rightarrow$ Draft Assembly.
- **State 2**: Draft Assembly $\rightarrow$ Polished Assembly.
- **State 3**: Polished Assembly $\rightarrow$ QC Metrics (CheckM/QUAST).
- **State 4**: QC Passed $\rightarrow$ Annotated Genome.

### 2. Go/No-Go Gates

The agent must stop and warn the user if:

- **Low Completeness**: CheckM completeness is $< 90\%$.
- **High Contamination**: CheckM contamination is $> 10\%$.
- **Fragmented Assembly**: N50 is unexpectedly low for a bacterial isolate.

## Installation & Environment

This meta-skill depends on the tools installed in its sub-skills:

- **Assembly**: `spades`, `skesa`, `flye`, `raven`, `autocycler`, `hybracter`, `unicycler`.
- **Polishing**: `medaka`, `pypolish`, `pypolca`, `dorado`.
- **Validation**: `quast`, `checkm`, `busco`.
- **Annotation**: `bakta`, `prokka`.

Refer to the project's environment management documentation for setup.

## Verification

- [ ] All four phases completed in sequence.
- [ ] Polishing sequence followed: Long $\rightarrow$ Short.
- [ ] CheckM completeness $> 95\%$ and contamination $< 5\%$.
- [ ] Final annotation produced in GFF and GenBank formats.
