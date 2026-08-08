# Bacterial Genome Analysis Skills

This meta-skill orchestrates the end-to-end reconstruction of bacterial genomes, transforming cleaned sequencing reads into a validated, polished, and annotated genomic sequence. It implements the **"Finished Genome"** paradigm, ensuring that assembly errors are corrected before biological features are labeled.

> **Dual-Audience Design**: This meta-skill is designed to serve **both AI coding agents and human bioinformaticians**. The structured triggers, evidence chains, and Go/No-Go gates guide autonomous execution, while the embedded "When to Use", "Why This Tool", "Conceptual Background", and "Troubleshooting" sections provide human readers with the intuition to make informed decisions.

## Pipeline Overview

The analysis follows a strict **4-phase evidence chain** (building upon upstream read QC, covered by the separate `read-qc-trimming` skill). Moving to a subsequent phase requires passing a "Go/No-Go" quality gate.

| # | Phase | Goal | Key Tools | Sub-Skill |
|:---|:---|:---|:---|:---|
| **1** | **Assembly** (The Draft) | Generate initial contigs from cleaned reads. | `SPAdes`, `Flye`, `Unicycler`, `Hybracter`, `Autocycler`, `Dragonflye`, `MEGAHIT`, `Canu`, `Raven`, `Miniasm`+`Racon` | `/assembly` |
| **2** | **Polishing** (The Correction) | Correct base-level errors (INDELs, SNPs). | `Medaka`/`NanoPolish` (Long) $\rightarrow$ `Pypolish`/`Pypolca` (Short) | `/polishing` |
| **3** | **Validation** (The Quality Gate) | Quantify contiguity, completeness, contamination. | `CheckM` ($>95\%$ C, $<5\%$ X), `QUAST`, `BUSCO`, `Kraken2` | `/validation` |
| **4** | **Annotation** (The Labeling) | Identify and label biological features. | `Bakta` (Recommended), `Prokka`, `DFAST`, `PGAP` | `/annotation` |

### Phase Selection Logic

- **Phase 1a (Short-Read)**: Use Illumina data only $\rightarrow$ produces fragmented drafts.
- **Phase 1b (Long-Read)**: Use ONT/PacBio data only $\rightarrow$ produces near-complete genomes.
- **Phase 1c (Hybrid)**: Use both $\rightarrow$ the **gold standard** for closed genomes.

## When to Use This Skill

✅ **Use this skill** when you need to:
- Reconstruct a bacterial genome **de novo** (without a reference).
- Achieve a **complete, closed genome** (single contig per replicon).
- Identify AMR genes, virulence factors, or metabolic pathways.
- Submit a genome to NCBI (requires GenBank annotation).

❌ **Do NOT use this skill** for:
- Reference-based variant calling (use a variant calling pipeline).
- Eukaryotic, viral, or metagenomic data (different paradigms apply).
- Raw read statistics (use a read QC skill).

## Installation

A `pixi.toml` is provided for one-step environment setup. Clone the repository and run:

```bash
# 1. Clone the repository
git clone https://github.com/cheahhl814/bacterial-genome-analysis.git
cd bacterial-genome-analysis

# 2. Initialize the pixi environment (installs all 29 tools)
pixi install

# 3. Verify the environment
pixi run assembly-short   # Tests that short-read assembly tools are available
```

All 29 required tools are available on `conda-forge` and `bioconda` channels, verified via `pixi search`.

## How to use this skill

### For AI Agents

Import the skill URL into your agent harness:

```
Import the skill from https://github.com/cheahhl814/bacterial-genome-analysis
```

The agent will respond to triggers such as *"assemble bacterial genome"*, *"complete bacterial assembly"*, or *"annotate bacterial genome"* and execute the 4-phase workflow.

### For Human Users

1. **Read the Master `SKILL.md`** for the pipeline architecture and glossary.
2. **Navigate to the relevant sub-skill** based on your data type (short/long/hybrid).
3. **Follow the "When to Use", "Why This Tool", and "Troubleshooting" sections** for decision support.
4. **Use the Go/No-Go gates** as checkpoints to ensure quality at each phase.

## File Structure

```
bacterial-genome-analysis/
├── SKILL.md                              # Master Orchestrator (Audience, When to Use, Glossary)
├── README.md                              # This file (Public overview)
├── pixi.toml                              # Conda/pixi environment declaration
├── assembly/
│   ├── short-read-assembly/SKILL.md     # De Bruijn Graph paradigm; SPAdes/SKESA/MEGAHIT
│   ├── long-read-assembly/SKILL.md      # OLC paradigm; Flye/Autocycler/Dragonflye
│   └── hybrid-assembly/SKILL.md        # Hybrid paradigms; Unicycler/Dragonflye/Hybracter
├── polishing/
│   └── genome-polishing/SKILL.md        # Two-stage polishing (Long-read → Short-read)
├── validation/
│   └── assembly-qc/SKILL.md             # Three Pillars of QC (Contiguity/Completeness/Contamination)
└── annotation/
    └── genome-annotation/SKILL.md       # Bakta-centric annotation with UniRef database
```

## License

This skill's text and code are released under the MIT License.