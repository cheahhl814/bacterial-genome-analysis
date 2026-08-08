---
name: assembly-qc
description: Quantify the quality, completeness, and contamination of a bacterial genome assembly. This skill ensures that an assembly is "finished" enough for downstream annotation and comparative genomics using CheckM, QUAST, BUSCO, and Kraken2.
version: 4
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

## Audience

This skill serves two purposes:
- **AI Agents**: Triggered by phrases like *"validate assembly"* or *"check assembly quality"*. Must execute all four QC steps and apply the Go/No-Go gates.
- **Human Users**: Provides conceptual background, decision rationale, and troubleshooting guidance.

## When to Use This Skill

Use this skill if:
- You have a **polished or unpolished** assembly that needs validation.
- You want to determine if the assembly meets **MIMAG high-quality standards** ($>95\%$ completeness, $<5\%$ contamination).
- You suspect **contamination** or **fragmentation** in your assembly.
- You need to compare multiple assemblies (e.g., from different assemblers).

Do NOT use this skill if:
- You only have raw reads (use a read QC skill first).
- You are working with metagenomic data (different QC paradigms apply; use MetaQUAST and MAG-specific tools).

## Description

Assembly quality control (QC) prevents the use of fragmented or contaminated genomes in downstream analysis. This skill transforms a FASTA assembly into a set of quantitative metrics (Completeness, Contamination, Contiguity).

## Conceptual Background

**The Three Pillars of Assembly Quality:**

1. **Contiguity** (QUAST): Is the assembly in few, long contigs? Measured by N50, L50, and total contig count.
2. **Completeness** (CheckM, BUSCO): Does the assembly contain all expected genes? Measured by the presence of lineage-specific single-copy markers.
3. **Contamination** (Kraken2): Does the assembly contain sequences from other organisms? Measured by taxonomic classification of contigs.

**Why are these metrics important?** An assembly with low completeness will miss real genes, leading to false-negative annotations. An assembly with high contamination will produce false-positive annotations from other organisms.

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

## Troubleshooting

| Symptom                                          | Likely Cause                                                   | Recommended Action                                                            |
|:------------------------------------------------ |:-------------------------------------------------------------- |:----------------------------------------------------------------------------- |
| **CheckM fails to place assembly in a lineage**   | Novel organism or highly contaminated assembly.                | Use `--reduced_tree` flag; manually specify lineage with `--taxon_list`.       |
| **CheckM reports very high contamination ($>10\%$)** | Multiple organisms in the assembly.                          | Identify and remove contaminating contigs using `Kraken2`.                     |
| **BUSCO database download fails**                 | Network issues or server unavailability.                       | Retry; use `busco --download_path` to specify a local mirror.                  |
| **QUAST reports very high misassembly count**     | Repetitive genome or incorrect assembler parameters.           | Try a different assembler; verify with read mapping.                            |
| **Kraken2 database too large to download**        | Limited disk space.                                            | Use a smaller database (e.g., `minikraken2`); use `centrifuge` as alternative.|

## Verification

- [ ] `quast_output/report.html` generated.
- [ ] `CheckM` reports completeness $> 95\%$ and contamination $< 5\%$.
- [ ] `BUSCO` results indicate high completeness for the target lineage.
- [ ] `Kraken2` report confirms sample purity (no multi-organism contamination).