# Bacterial Genome Analysis — Tool Documentation Corpus

Ingested from official GitHub repos and documentation sites on 2026-08-15.
Each subdirectory contains the README.md (or equivalent documentation) for a tool used in this skill.

## Tools by Phase

### Assembly (Phase 1)
| Tool | Directory | Source |
|------|-----------|--------|
| SPAdes | `spades/` | https://github.com/ablab/spades |
| SKESA | `skesa/` | https://github.com/ncbi/SKESA |
| MEGAHIT | `megahit/` | https://github.com/voutcn/megahit |
| Flye | `flye/` | https://github.com/fenderglass/Flye |
| Raven | `raven/` | https://github.com/lbcb-sci/raven |
| Canu | `canu/` | https://github.com/marbl/canu |
| miniasm | `miniasm/` | https://github.com/lh3/miniasm |
| Unicycler | `unicycler/` | https://github.com/rrwick/Unicycler |
| Dragonflye | `dragonflye/` | https://github.com/rpetit3/dragonflye |
| Hybracter | `hybracter/` | https://github.com/gbouras13/hybracter |
| Autocycler | `autocycler/` | https://github.com/rrwick/Autocycler |

### Polishing (Phase 2)
| Tool | Directory | Source |
|------|-----------|--------|
| Medaka | `medaka/` | https://github.com/nanoporetech/medaka |
| Nanopolish | `nanopolish/` | https://github.com/jts/nanopolish |
| Racon | `racon/` | https://github.com/lbcb-sci/racon |
| Polypolish | `polypolish/` | https://github.com/rrwick/Polypolish |
| Pypolca | `pypolca/` | https://github.com/gbouras13/pypolca |
| BWA-MEM2 | `bwa-mem2/` | https://github.com/bwa-mem2/bwa-mem2 |
| Minimap2 | `minimap2/` | https://github.com/lh3/minimap2 |
| Samtools | `samtools/` | https://github.com/samtools/samtools |

### Validation (Phase 3)
| Tool | Directory | Source |
|------|-----------|--------|
| QUAST | `quast/` | https://github.com/ablab/quast |
| CheckM | `checkm/` | https://github.com/Ecogenomics/CheckM |
| CheckM2 | `checkm2/` | https://github.com/chklovski/CheckM2 |
| BUSCO | `busco/` | https://busco.ezlab.org/ |
| Kraken2 | `kraken2/` | https://github.com/DerrickWood/kraken2 |

### Annotation (Phase 4)
| Tool | Directory | Source |
|------|-----------|--------|
| Bakta | `bakta/` | https://github.com/oschwengers/bakta |
| Prokka | `prokka/` | https://github.com/tseemann/prokka |
| DFAST | `dfast/` | https://github.com/nigyta/dfast_core |

### Utility
| Tool | Directory | Source |
|------|-----------|--------|
| SeqKit | `seqkit/` | https://github.com/shenwei356/seqkit |

## Ingestion Method

- GitHub READMEs: Strategy 3 (clone + extract) from the docs-ingest skill.
- BUSCO: Strategy 5 (fetch_content from busco.ezlab.org user guide).
- All files are plain Markdown, converted from HTML/RST where needed.

## Usage

This corpus is for AI agent consumption. When the skill needs to know tool-specific flags, error patterns, or output formats, the agent should search this corpus rather than guessing.

```bash
# Search across all tool docs
grep -rn "flag\|option\|usage" docs-corpus/
```