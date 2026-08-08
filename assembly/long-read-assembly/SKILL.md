---
name: long-read-assembly
description: Assemble bacterial genomes from long-read sequencing data (ONT/PacBio). This skill implements the consensus assembly paradigm to resolve repeats and produce near-complete circular chromosomes and plasmids.
version: 1
updated: "2026-08-09"
triggers:
  - "assemble long reads"
  - "nanopore assembly"
  - "pacbio assembly"
  - "Flye"
  - "Raven"
  - "Autocycler"
  - "long-read bacterial assembly"
---

# Skill: long-read-assembly

## Description

Assemble bacterial genomes from long-read sequencing data. This skill moves beyond simple assembly by implementing a consensus approach to minimize structural errors and maximize contiguity.

## Prerequisites

- **Environment**: Active Pixi environment.
- **Upstream Evidence**: Cleaned long reads (`.fastq.gz`) from `skills/read-trimming-cleaning/SKILL.md`.

## Installation

```bash
pixi add flye raven autocycler
```

## Procedure

### 1. Primary Assembly (The Draft)

The agent selects an assembler based on data type and memory constraints.

| Read Type | Recommended Tool | Notes |
| :--- | :--- | :--- |
| **ONT / PacBio** | `Flye` | Extremely robust; excellent for plasmids. |
| **ONT (Fast/Low RAM)** | `Raven` | Very fast; low memory footprint. |

**Example (Flye):**
```bash
flye --nano-raw reads.fq.gz --out-dir flye_output/ --threads 8
# Result: flye_output/assembly.fasta
```

### 2. Consensus Assembly (The Refinement)

To avoid the "single-assembler bias" and structural errors, the agent MUST use a consensus tool.

**The Autocycler Paradigm**:
`Autocycler` is the successor to Trycycler. It generates multiple assembly attempts and finds the most consistent consensus.

```bash
# Run autocycler on the primary assembly and raw reads
autocycler --reads reads.fq.gz --assembly flye_output/assembly.fasta --out-dir autocycler_output/
```

## Interpretation Guidelines

- **Circularization**: Check if the assembly reports circular chromosomes or plasmids. This is the goal for bacterial genomes.
- **Contig Count**: A "perfect" assembly has one contig per replicon.

## Verification

- [ ] `assembly.fasta` (Flye/Raven) exists.
- [ ] `consensus.fasta` (Autocycler) produced.
- [ ] The agent has verified that circularization was attempted.
