---
name: long-read-assembly
description: Assemble bacterial genomes from long-read sequencing data (ONT/PacBio). This skill implements the consensus assembly paradigm to resolve repeats and produce near-complete circular chromosomes and plasmids, integrating quality filtering and depth downsampling.
version: 5
updated: "2026-08-14"
triggers:
  - "assemble long reads"
  - "nanopore assembly"
  - "pacbio assembly"
  - "Flye"
  - "Raven"
  - "Canu"
  - "Miniasm"
  - "Racon"
  - "Autocycler"
  - "Dragonflye"
  - "long-read bacterial assembly"
---

# Skill: long-read-assembly

## Audience

This skill serves two purposes:
- **AI Agents**: Triggered by phrases like *"assemble long reads"* or *"nanopore assembly"*. Must execute the strategy selection and verification steps below.
- **Human Users**: Provides conceptual background, decision rationale, and troubleshooting guidance.

## When to Use This Skill

Use this skill if:
- You have **long-read data** (ONT or PacBio HiFi).
- You need a **complete, closed genome** (single contig per replicon).
- You are working with a **highly repetitive** genome (long reads span repeats).
- You need to resolve **plasmids** or other extrachromosomal elements.

Do NOT use this skill if:
- You only have Illumina short reads (use `short-read-assembly` instead).
- You have both short and long reads (use `hybrid-assembly` for the highest accuracy).
- You need extreme base-level accuracy without short-read polishing (this skill assumes polishing will follow).

## Description

Assemble bacterial genomes from long-read sequencing data. This skill moves beyond simple assembly by implementing a consensus approach (via Autocycler or Dragonflye) to minimize structural errors and maximize contiguity.

## Conceptual Background

Long-read assemblers use the **Overlap-Layout-Consensus (OLC)** or **de Bruijn-like graph (e.g., Flye)** paradigms:
1. **Overlap**: Find overlaps between all reads (since reads can span repeats).
2. **Layout**: Arrange reads into a graph structure (e.g., a string graph).
3. **Consensus**: Generate the consensus sequence from the aligned reads.

**Why does this produce complete genomes?** Long reads ($>10,000$ bp) are longer than most bacterial repeats (e.g., rRNA operons), allowing the assembler to span repetitive regions and produce a single contig per chromosome or plasmid.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: Cleaned long reads (`.fastq.gz`) produced by the `read-qc-trimming` skill.
- **Required Tools**: 
  - **Assembly**: `Flye`, `Raven`, `Canu`, `Miniasm` + `Racon`.
  - **Consensus**: `Autocycler`, `Dragonflye`.

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add flye raven canu miniasm racon autocycler dragonflye
```

## Procedure

### 1. Primary Assembly (The Draft)
The agent selects an assembler based on data type and memory constraints.

| Read Type                | Recommended Tool | Why This Tool?                                                                                                                                                  |
|:------------------------ |:---------------- |:----------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **ONT / PacBio (Standard)** | `Flye`           | Extremely robust for noisy long reads; excellent for plasmids. Uses repeat graphs to resolve ambiguities.                                                       |
| **ONT (Fast/Low RAM)**   | `Raven`          | Very fast and low memory. Ideal for high-throughput ONT datasets.                                                                                              |
| **PacBio (HiFi)**        | `Flye --pacbio-hifi` | Optimized for the high accuracy of HiFi reads; produces highly accurate assemblies.                                                                         |
| **ONT (High Accuracy)**  | `Canu`           | Legacy gold standard; uses adaptive k-mer weighting. High memory usage ($>30$ GB RAM for large genomes).                                                        |
| **Minimal Memory**       | `Miniasm` + `Racon` | Sketch-based assembly. Extremely fast but requires extensive polishing (multiple Racon rounds).                                                                |

**Example (Flye):**
```bash
# Flye does not recursively create nested output directories — if --out-dir
# has a parent that doesn't exist yet (e.g. assembly/flye/), it crashes with
# FileNotFoundError instead of creating it. mkdir -p first (verified 2026-08-14).
mkdir -p flye_output/
flye --nano-raw cleaned_reads.fastq.gz \
     --out-dir flye_output/ \
     --threads 8 \
     --genome-size 3m
# Result: flye_output/assembly.fasta
```

### 2. Consensus Assembly (The Refinement)

To avoid the "single-assembler bias" and structural errors, the agent MUST use a consensus tool.

#### Path A: Autocycler (Standard Paradigm)
`Autocycler` is the successor to Trycycler. It generates multiple assembly attempts and finds the most consistent consensus.

```bash
# Subsample reads (Autocycler requires multiple subsets)
autocycler subsample --reads cleaned_reads.fastq.gz --out_dir autocycler_out/

# Run multiple primary assemblies (e.g., Flye, Raven, Miniasm+Racon)
# Then combine into a consensus:
autocycler combine --assemblies all_assemblies/*.fasta --out_dir combined_out/
autocycler resolve --inputs combined_out/ --out_dir resolved_out/
```
*Final Result:* `resolved_out/consensus.fasta`

#### Path B: Dragonflye (Automated Wrappers)
`Dragonflye` is an automated wrapper for long-read assembly using Flye + Medaka + Polypolish/Pypolca.
```bash
dragonflye --reads cleaned_reads.fastq.gz --outdir dragonflye_out/ \
           --assembler flye --polish-rounds 3
```

## Interpretation Guidelines

- **Circularization**: Check if the assembly reports circular chromosomes or plasmids. This is the goal for bacterial genomes.
- **Contig Count**: A "perfect" assembly has one contig per replicon (chromosome + plasmids).
- **N50**: For a single circular chromosome, the N50 will be approximately the genome size.

## Troubleshooting

| Symptom                                  | Likely Cause                                              | Recommended Action                                                                |
|:---------------------------------------- |:---------------------------------------------------------- |:--------------------------------------------------------------------------------- |
| **High memory usage / OOM with Flye**    | Very high coverage ($>100\times$) or very long reads.      | Subsample reads using `Rasusa` to a target coverage of $50\text{-}100\times$.      |
| **Multiple contigs instead of one circular chromosome** | Incomplete assembly; coverage gaps or repeat resolution failure. | Increase sequencing depth; try `Autocycler` for consensus.                |
| **Flye fails to circularize plasmids**   | Plasmid loss or coverage gaps in plasmid.                  | Check coverage uniformity; consider increasing long-read depth.                    |
| **Consensus assembly (Autocycler) fails** | Inconsistent input assemblies (different parameters).    | Ensure all input assemblies use the same read set; check Autocycler logs.           |

## Verification

- [ ] Primary assembly (Flye/Raven) exists.
- [ ] Consensus assembly (`Autocycler` or `Dragonflye`) exists.
- [ ] The agent has verified that circularization was attempted.