---
name: assembly-qc
description: Quantify the quality, completeness, and contamination of a bacterial genome assembly. This skill ensures that an assembly is "finished" enough for downstream annotation and comparative genomics.
version: 1
updated: "2026-08-09"
triggers:
  - "validate assembly"
  - "check assembly quality"
  - "QUAST"
  - "CheckM"
  - "BUSCO"
  - "genome completeness"
  - "assembly contamination"
---

# Skill: assembly-qc

## Description

Assembly quality control (QC) prevents the use of fragmented or contaminated genomes in downstream analysis. This skill transforms a FASTA assembly into a set of quantitative metrics (Completeness, Contamination, Contiguity).

## Prerequisites

- **Environment**: Active Pixi environment.
- **Upstream Evidence**: A polished assembly (`.fasta`) from `skills/bacterial-genome-analysis/polishing/`.

## Installation

```bash
pixi add quast checkm busco
```

## Procedure

### 1. Structural Analysis (`QUAST`)

QUAST provides the "physical" metrics of the assembly.

```bash
quast.py assembly.fasta -o quast_output/
```
- **Key Metrics**: N50, Total Length, Number of Contigs, L50.

### 2. Biological Validation (`CheckM`)

CheckM is the gold standard for bacterial genomics. It uses lineage-specific single-copy genes to estimate completeness and contamination.

```bash
# 1. Add assembly to CheckM
checkm lineage_arc_sa assembly.fasta output_dir/
# 2. Run QC
checkm qa assembly.fasta output_dir/
```
- **Acceptance Criteria**: 
  - **Completeness**: $> 95\%$ (for high-quality isolates).
  - **Contamination**: $< 5\%$.

### 3. Evolutionary Completeness (`BUSCO`)

BUSCO verifies that the assembly contains the expected universal genes for the chosen lineage.

```bash
busco -i assembly.fasta -l bacteria_odb10 -o busco_output/ -m genome
```
- **Key Metrics**: \% Complete, \% Fragmented, \% Missing.

## Interpretation Guidelines

| Symptom | Inference | Action |
| :--- | :--- | :--- |
| **Low Completeness** | Incomplete sequencing or failed assembly. | Re-evaluate assembly parameters or increase coverage. |
| **High Contamination** | Mixed culture or assembly artifacts. | Use `CheckM` to identify contaminating contigs; filter. |
| **Low N50 / Many Contigs** | Fragmented assembly. | Try hybrid assembly or use `Autocycler` for consensus. |

## Verification

- [ ] `quast_output/report.html` generated.
- [ ] `CheckM` reports completeness $> 95\%$ and contamination $< 5\%$.
- [ ] `BUSCO` results indicate high completeness for the target lineage.
