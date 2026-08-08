---
name: hybrid-assembly
description: Combine short and long reads to assemble high-fidelity, complete bacterial genomes. This skill implements both Unicycler (short-read first) and Dragonflye (long-read first) strategies to resolve repeats and close gaps.
version: 4
updated: "2026-08-09"
triggers:
  - "hybrid assembly"
  - "combine short and long reads"
  - "Unicycler"
  - "Dragonflye"
  - "complete bacterial genome"
  - "close gaps"
---

# Skill: hybrid-assembly

## Audience

This skill serves two purposes:
- **AI Agents**: Triggered by phrases like *"hybrid assembly"* or *"combine short and long reads"*. Must execute the strategy selection and verification steps below.
- **Human Users**: Provides conceptual background, decision rationale, and troubleshooting guidance.

## When to Use This Skill

Use this skill if:
- You have **both short and long reads** (e.g., Illumina + ONT).
- You need the **highest possible accuracy** (uses both data types).
- You want to resolve **complex repeats** and close gaps.
- You are preparing a genome for **NCBI submission** (requires high-quality, closed assemblies).

Do NOT use this skill if:
- You only have one read type (use `short-read-assembly` or `long-read-assembly` instead).

## Description

Assemble bacterial genomes using both short (Illumina) and long (ONT/PacBio) reads. This is the gold standard for producing "closed" genomes where chromosomes and plasmids are fully resolved without gaps. The `nf-core/bacass` pipeline supports two primary paradigms: Unicycler and Dragonflye.

## Conceptual Background

Hybrid assembly combines the strengths of both technologies:
- **Short reads**: High base-level accuracy ($Q30+$, $>99.9\%$ accuracy).
- **Long reads**: Long-range structural information (spans repeats).

**The Two Paradigms:**
1. **Short-Read First (Unicycler)**: Build a high-quality short-read assembly graph, then use long reads to scaffold and close gaps.
2. **Long-Read First (Dragonflye)**: Build a long-read assembly, then use short reads to correct base-level errors (polishing).

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: 
  - Cleaned short reads (`.fastq.gz`) produced by the `read-qc-trimming` skill.
  - Cleaned long reads (`.fastq.gz`) produced by the `read-qc-trimming` skill.
- **Required Tools**:
  - **Assembly**: `Unicycler` (Short-read first), `Dragonflye` (Long-read first).

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add unicycler dragonflye spades flye medaka pypolish pypolca
```

## Procedure

### 1. Strategy Selection

| Paradigm             | Recommended Tool | Why This Tool?                                                                                                                                  |
|:-------------------- |:---------------- |:------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Short-Read First** | `Unicycler`      | Excellent for low-coverage long reads. Uses SPAdes to build a high-quality short-read graph, then bridges contigs with long reads.              |
| **Long-Read First**  | `Dragonflye`     | Highly accurate for high-quality long reads. Uses Flye to build a long-read assembly, then polishes with short reads (Pypolish/Pypolca).        |
| **Automated / Modern** | `Hybracter`    | Scalable and updated for modern tools. Implements a long-read-first approach with automated polishing.                                          |

### 2. Execution

#### Path A: Unicycler (Short-Read First)
Unicycler is the most widely used hybrid assembler. It builds an SPAdes assembly graph, then bridges contigs using long reads.

```bash
unicycler -1 R1.fq.gz -2 R2.fq.gz \
          -l long_reads.fastq.gz \
          -o unicycler_output/ \
          -t 8
```
*Key Flags:*
- `-l`: Long reads (FastA/FastQ, gzipped supported).
- `--no_miniasm`: Skip the long-read assembly step if coverage is low.

#### Path B: Dragonflye (Long-Read First)
Dragonflye wraps Flye (or other long-read assemblers) and applies short-read polishing.

```bash
dragonflye --reads long_reads.fastq.gz \
           --R1 R1.fq.gz --R2 R2.fq.gz \
           --outdir dragonflye_out/ \
           --assembler flye \
           --polish-rounds 3 \
           --threads 8
```

## Interpretation Guidelines

- **Closure**: Check for circular contigs. Unicycler and Dragonflye both attempt to circularize the genome.
- **Consistency**: Ensure the total genome size matches the expected size for the organism.
- **Plasmids**: Pay special attention to plasmid reconstruction. Unicycler excels at separating plasmids with similar sequences.

## Troubleshooting

| Symptom                                                | Likely Cause                                                       | Recommended Action                                                       |
|:------------------------------------------------------ |:------------------------------------------------------------------ |:------------------------------------------------------------------------ |
| **Unicycler runs very slowly**                          | Low short-read coverage or excessive read count.                    | Subsample short reads to $50\times$ coverage; reduce thread count if memory-bound. |
| **Plasmids not circularized**                          | Insufficient long-read coverage of plasmid; plasmid loss.           | Increase long-read depth; check for coverage uniformity.                 |
| **Dragonflye produces fragmented assembly**             | Poor-quality long reads or insufficient coverage.                  | Use `Filtlong` to filter low-quality reads; increase sequencing depth.    |
| **Misassemblies at repeat boundaries**                  | Long-read errors or incorrect assembler parameters.                | Try the alternative paradigm (Unicycler vs. Dragonflye); increase coverage. |

## Verification

- [ ] `assembly.fasta` exists in the output directory.
- [ ] The assembly is validated for circularity where applicable (e.g., via Bandage or QUAST).
- [ ] Total assembly length matches the target species size.
- [ ] Plasmids are fully resolved or documented if fragmented.