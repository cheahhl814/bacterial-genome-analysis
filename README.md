# Bacterial Genome Analysis Skills

This meta-skill orchestrates the end-to-end reconstruction of bacterial genomes, transforming raw sequencing reads into a validated, polished, and annotated genomic sequence. It implements the "Finished Genome" paradigm, ensuring that assembly errors are corrected before biological features are labeled.

## Pipeline Overview

The analysis follows a strict sequential evidence chain. Moving to a subsequent phase requires passing a "Go/No-Go" quality gate.

1. **Assembly (The Draft)** (`/assembly`)
   
   - **Input**: Short reads, Long reads, or both (Hybrid).
   - **Output**: Draft FASTA assembly.
   - **Key Tools**: `SPAdes`, `Flye`, `Autocycler`, `Hybracter`.

2. **Polishing (The Correction)** (`/polishing`)
   
   - **Input**: Draft FASTA + Reads.
   - **Output**: Polished FASTA assembly.
   - **Key Tools**: `Medaka`/`Dorado` (Long-read) $\rightarrow$ `Pypolish`/`Pypolca` (Short-read).

3. **Validation (The Quality Gate)** (`/validation`)
   
   - **Input**: Polished FASTA.
   - **Output**: QC metrics (Completeness, Contamination).
   - **Key Tools**: `CheckM`, `QUAST`, `BUSCO`.

4. **Annotation (The Labeling)** (`/annotation`)
   
   - **Input**: Validated FASTA.
   - **Output**: Annotated GFF/GBK files.
   - **Key Tools**: `Bakta` (Recommended), `Prokka`, `PGAP`.

## How to use this skill

This skill is designed for use by AI coding agents. To load the pipeline, import the repository:

```
Import the skill from https://github.com/cheahhl814/bacterial-genome-analysis
into your skills directory.
```

The agent will respond to triggers such as *"assemble bacterial genome"*, *"complete bacterial assembly"*, or *"annotate bacterial genome"* and follow the a-priori structured workflow.

## File Structure

```
bacterial-genome-analysis/
├── SKILL.md                              # Master Orchestrator (The Evidence Chain)
├── README.md                              # This file
├── assembly/
│   ├── short-read-assembly/SKILL.md     # Short-read (SPAdes/SKESA)
│   ├── long-read-assembly/SKILL.md      # Long-read (Flye/Autocycler)
│   └── hybrid-assembly/SKILL.md        # Hybrid (Hybracter/Unicycler)
├── polishing/
│   └── genome-polishing/SKILL.md        # Polishing sequence (Long -> Short)
├── validation/
│   └── assembly-qc/SKILL.md             # QC (CheckM/QUAST/BUSCO)
└── annotation/
    └── genome-annotation/SKILL.md       # Annotation (Bakta/Prokka)
```

## License

This skill's text and code are released under the MIT License.
