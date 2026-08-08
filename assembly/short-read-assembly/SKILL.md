---
name: short-read-assembly
description: Assemble bacterial genomes from short-read sequencing data (Illumina). This skill focuses on producing the most contiguous draft possible from paired-end reads, utilizing De Bruijn graph assemblers and integrating quality control to ensure data integrity before assembly.
version: 4
updated: "2026-08-09"
triggers:
  - "assemble short reads"
  - "illumina assembly"
  - "SPAdes"
  - "SKESA"
  - "MEGAHIT"
  - "bacterial assembly short-read"
  - "Unicycler short reads"
---

# Skill: short-read-assembly

## Audience

This skill serves two purposes:
- **AI Agents**: Triggered by phrases like *"assemble short reads"* or *"illumina assembly"*. Must execute the strategy selection and verification steps below.
- **Human Users**: Provides conceptual background, decision rationale, and troubleshooting guidance.

## When to Use This Skill

Use this skill if:
- You only have **Illumina short reads** (paired-end, $\le 300$ bp).
- You need a quick draft for variant calling or SNP analysis.
- You have **metagenomic** data and need to bin contigs into species-level bins.

Do NOT use this skill if:
- You have long-read data (use `long-read-assembly` instead).
- You have both short and long reads (use `hybrid-assembly` for the best results).
- You need a completely closed genome (short reads cannot span long repeats).

## Description

Assemble bacterial genomes from short-read sequencing data. Since short reads cannot resolve large repetitive regions (e.g., rRNA operons, mobile elements), the result is typically a fragmented draft. This skill transforms cleaned FASTQ files into a FASTA assembly following the **nf-core/bacass** paradigm.

## Conceptual Background

Short-read assemblers use the **De Bruijn Graph** paradigm:
1. All reads are broken into **k-mers** (subsequences of length $k$).
2. Identical k-mers form nodes in a graph.
3. Overlapping k-mers (sharing $k-1$ bases) form edges.
4. The genome is reconstructed by finding an Eulerian path through the graph.

**Why does this produce fragmented assemblies?** Bacterial genomes contain long repetitive elements (e.g., rRNA operons of $5,000+$ bp). Since short reads (150-300 bp) are much shorter than these repeats, they cannot uniquely resolve them, causing the assembler to break the genome at each repeat boundary.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: Cleaned reads (`.fastq.gz`) produced by the `read-qc-trimming` skill.

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add spades skesa megahit kraken2
```

## Procedure

### 1. Strategy Selection

| Data Type / Goal                 | Recommended Tool              | Why This Tool?                                                                                                                                            |
|:-------------------------------- |:----------------------------- |:----------------------------------------------------------------------------------------------------------------------------------------------------------|
| **Standard (High Contiguity)**   | `SPAdes`                      | The community standard for small genomes. Uses multi-size De Bruijn graphs to handle variable coverage. The `--careful` flag adds mismatch correction. |
| **High-Throughput / Fast**       | `SKESA`                       | Significantly faster and lower memory than SPAdes. Uses a greedy assembly approach that avoids some SPAdes artifacts.                                    |
| **Metagenomes / Large Inputs**   | `MEGAHIT`                     | Specifically optimized for large, complex datasets (metagenomes). Uses succinct De Bruijn graphs to reduce memory.                                        |
| **Hybrid (requires long reads)** | `Unicycler` (Short-read mode) | Optimizes SPAdes k-mers and bridges contigs with long reads (refer to `hybrid-assembly` skill).                                                           |

### 2. Execution

#### Path A: SPAdes (Standard)

SPAdes uses a multi-k-mer approach to resolve complex genomic regions.

```bash
spades.py --careful \
          -t 8 \
          -1 R1.fq.gz -2 R2.fq.gz \
          -o spades_output/
# Final assembly: spades_output/scaffolds.fasta
```

*Note: The `--careful` flag reduces misassemblies by performing mismatch correction.*

#### Path B: SKESA (Fast)

```bash
skesa --reads R1.fq.gz R2.fq.gz --cores 8 --output assembly.fasta
```

#### Path C: MEGAHIT (Large/Complex)

```bash
megahit -1 R1.fq.gz -2 R2.fq.gz -o megahit_output/ -t 8
# Final assembly: megahit_output/final.contigs.fa
```

### 3. Contamination Verification (The Gate)

Before proceeding to polishing (if applicable) or annotation, the assembly MUST be checked for contamination.

```bash
kraken2 --db /path/to/kraken2_db --threads 8 \
        --output kraken2.report --report kraken2_summary.txt \
        --confidence 0.05 \
        spades_output/scaffolds.fasta
```

- **Acceptance Criteria**: $>95\%$ of contigs must align to the expected genus.

## Interpretation Guidelines

- **Contiguity**: Check the number of contigs. A high number of contigs is expected for short-read only assemblies (typically $50\text{-}500+$ contigs for a bacterial genome).
- **N50**: Use as a rough proxy for assembly quality (higher is better). For a typical bacterial genome, an N50 of $>50,000$ bp is reasonable.
- **Misassemblies**: SPAdes `--careful` mitigates this; check QUAST for misassembly metrics.

## Troubleshooting

| Symptom                              | Likely Cause                                                  | Recommended Action                                                            |
|:------------------------------------ |:-------------------------------------------------------------- |:----------------------------------------------------------------------------- |
| **Very high number of contigs ($>500$)** | Low coverage or poor-quality reads.                          | Re-evaluate upstream QC; ensure coverage is $>30\times$.                       |
| **Assembly length much larger than expected** | Contamination from another organism.                      | Run `Kraken2` and filter out contaminating contigs.                            |
| **Assembly length much smaller than expected** | Aggressive trimming or failed assembly.                     | Reduce QC stringency; check for adapter contamination.                         |
| **Many misassemblies reported by QUAST** | Repetitive regions or heterozygous sites (if not haploid). | Use `--careful` mode (SPAdes); consider downsampling or hybrid assembly.       |

## Verification

- [ ] `scaffolds.fasta` or `assembly.fasta` exists.
- [ ] The total assembly length is approximately equal to the expected genome size of the species.
- [ ] `Kraken2` report confirms the sample matches the expected organism.