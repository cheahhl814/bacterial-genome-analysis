---
name: assembly-qc
description: Quantify the quality, completeness, and contamination of a bacterial genome assembly. This skill ensures that an assembly is "finished" enough for downstream annotation and comparative genomics using CheckM, QUAST, BUSCO, and Kraken2.
version: 2
updated: "2026-08-09"
triggers:
  - "validate assembly"
  - "check assembly quality"
  - "QUAST"
  - "CheckM"
  - "BUSCO"
  - "Kraken2"
  - "genome completeness"
  - "assembly contamination"
---

# Skill: assembly-qc

## Description

Assembly quality control (QC) prevents the use of fragmented or contaminated genomes in downstream analysis. This skill transforms a FASTA assembly into a set of quantitative metrics (Completeness, Contamination, Contiguity).

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: A polished assembly (`.fasta`) from `skills/bacterial-genome-analysis/polishing/`.
- **Required Tools**: 
  - `QUAST` (Structural contiguity).
  - `CheckM` (Lineage-based completeness/contamination).
  - `BUSCO` (Ortholog-based completeness).
  - `Kraken2` (Taxonomic contamination check).

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add quast checkm-genome busco kraken2
```

## Procedure

### 1. Structural Analysis (`QUAST`)

QUAST provides the "physical" metrics of the assembly.

```bash
quast.py assembly.fasta -o quast_output/ --threads 8
```
*Key Metrics:*
- **N50**: Half the assembly is in contigs of this length or longer.
- **Total Length**: Should match expected genome size.
- **Number of Contigs**: Lower is better; 1 for a closed genome.
- **L50**: Number of contigs covering 50\% of the genome.

### 2. Biological Validation (`CheckM`)

CheckM is the gold standard for bacterial genomics. It uses lineage-specific single-copy genes to estimate completeness and contamination.

```bash
# 1. Place assembly in a directory
mkdir -p checkm_input && cp assembly.fasta checkm_input/

# 2. Run CheckM lineage workflow
checkm lineage_wf -t 8 -x fa checkm_input/ checkm_output/

# 3. Summarize results
checkm qa checkm_output/lineage.ms checkm_output/ -o 1
```
*Acceptance Criteria (MIMAG standards):*
- **Completeness**: $> 95\%$ (for high-quality isolates).
- **Contamination**: $< 5\%$.

### 3. Evolutionary Completeness (`BUSCO`)

BUSCO verifies that the assembly contains the expected universal genes for the chosen lineage.

```bash
busco -i assembly.fasta \
      -l bacteria_odb10 \
      -o busco_output/ \
      -m genome \
      --cpu 8
```
*Key Metrics:*
- **Complete BUSCOs (C)**: Ideally $> 95\%$.
- **Fragmented (F)**: Ideally $< 5\%$.
- **Missing (M)**: Ideally $< 5\%$.

### 4. Contamination Check (`Kraken2`)

Ensure the assembly does not contain sequences from unexpected organisms.

```bash
kraken2 --db /path/to/kraken2_db \
        --threads 8 \
        --output kraken2.out --report kraken2.report \
        --confidence 0.05 \
        assembly.fasta
```
*Action*: Any contig assigned to a different taxonomic class (e.g., human, plant, or different bacteria) should be flagged for removal.

## Interpretation Guidelines

| Symptom | Inference | Action |
| :--- | :--- | :--- |
| **Low Completeness** | Incomplete sequencing or failed assembly. | Re-evaluate assembly parameters or increase coverage. |
| **High Contamination** | Mixed culture or assembly artifacts. | Use `Kraken2` to identify contaminating contigs; filter. |
| **Low N50 / Many Contigs** | Fragmented assembly. | Try hybrid assembly or use `Autocycler` for consensus. |
| **High Missing BUSCOs** | Incomplete capture of conserved genes. | Check sequencing depth; consider repeat resolution tools. |

## Verification

- [ ] `quast_output/report.html` generated.
- [ ] `CheckM` reports completeness $> 95\%$ and contamination $< 5\%$.
- [ ] `BUSCO` results indicate high completeness for the target lineage.
- [ ] `Kraken2` report confirms sample purity (no multi-organism contamination).