---
name: bacterial-genome-analysis-runner
description: Thin Nextflow DSL2 runner (v5.1, opt-in) wrapping the bacterial-genome-analysis bash sub-skills. Mirrors nf-core/bacass resource layout. Use for long-running production runs, HPC/cloud execution, or cohort assembly — not for single-machine dev iteration. Provides 8 modules (SPAdes / Flye / Unicycler / Medaka / Polypolish / Pypolca / QUAST / BUSCO / CheckM / Bakta) + 3 subworkflows (preflight-to-polish, polish-to-qc, qc-to-annotation). Bash recipes remain the source of truth and the default. Triggers: "nextflow bacterial genome", "nextflow bacass", "nextflow assembly pipeline", "nextflow runner".
version: 5.1.0
updated: "2026-08-16"
triggers:
  - "nextflow bacterial genome"
  - "nextflow bacass"
  - "nextflow assembly pipeline"
  - "nextflow runner"
  - "nf-core bacass"
---

# Nextflow Runner — bacterial-genome-analysis (v5.1)

This sub-skill ships a thin Nextflow DSL2 wrapper around the bash recipes in the parent `bacterial-genome-analysis` skill. **Bash is the source of truth and the default.** Reach for the runner only when you need one of: HPC/cloud execution, resume across long runs, nf-core-style trace reports, or batch execution across a cohort of isolates.

## Audience

1. **AI Coding Agents** — trigger via the phrases above. When invoked, follow the protocol below: validate params, confirm the chosen mode (short / long / hybrid), read or generate a sample sheet, and let Nextflow orchestrate.
2. **Human bioinformaticians** — for production, HPC, or cohort runs. Bash recipes are simpler for single-machine single-isolate dev work.

## When to Use

**Do** use the runner when:

- You are running ≥ 3 isolates in batch.
- You want HPC / SLURM / cloud execution.
- You want trace / report / timeline + `-resume` for long pipelines.
- You want to satisfy a reviewer who requires nf-core-style provenance.

**Don't** use the runner when:

- You are doing single-machine single-isolate dev iteration — bash is faster.
- You cannot install Nextflow ≥ 23.10.0 — see Prerequisites.
- Your output dir already exists with mixed files — runner will fail on `publishDir` overwrite; clean or pick a fresh outdir.

## Prerequisites

- **Nextflow ≥ 23.10.0** (tested on 24.10.6).
- **Java 17+** (Nextflow bundles a JDK check).
- **Container runtime** — Docker, Singularity / Apptainer, or Charliecloud. Profile `standard` runs locally without containers (assumes tools on PATH or in pixi env).
- **pixi** (or conda + mamba) for the bash recipes — runner can run with bare tools in PATH; pixi is recommended.
- For the test profile, none — runs `-stub-run` style.

### Verifying

```bash
nextflow -version
# Must show: N E X T F L O W  ~  version 23.10.0 or later, DSL2
```

## Installation

The runner is bundled with the parent skill at `runners/nextflow-runner/`. No `pixi add nextflow` is needed (Nextflow runs outside the pixi env, via the host shell) — but if you want it pinned, you may add it locally:

```bash
# Optional: pin Nextflow in your global environment (NOT in pixi.toml)
curl -s https://get.nextflow.io | bash
mkdir -p ~/.local/bin && mv nextflow ~/.local/bin/

# Verify
nextflow -version
```

You do NOT need to clone a separate repo — the runner ships with this skill:

```bash
cd /path/to/bacterial-genome-analysis/
ls runners/nextflow-runner/
# main.nf  nextflow.config  SKILL.md
# modules/  subworkflows/  conf/
```

## Quick Start

`--bakta_db`, `--kraken2_db`, and `--busco_lineage`'s download path all default
to the skill's reusable database cache at `../../assets/` (see
`assets/README.md`) — if you already populated it via a bash sub-skill run
(e.g. `bakta_db download -o "$SKILL_ROOT/assets/bakta_db"`), you don't need
to pass these flags at all. Pass them explicitly only to point at a
different location.

```bash
# Single isolate, short reads
nextflow run runners/nextflow-runner/main.nf \
    --reads 'data/sample1/*_{1,2}.fq.gz' \
    --mode short \
    --outdir results/sample1 \
    --run_bakta true \
    -profile docker

# Single isolate, long reads (ONT/HiFi)
nextflow run runners/nextflow-runner/main.nf \
    --long_reads 'data/sample1/*.fq.gz' \
    --mode long \
    --outdir results/sample1 \
    -profile docker

# Cohort of N isolates (sample sheet)
nextflow run runners/nextflow-runner/main.nf \
    --sample_sheet samples.csv \
    --mode short \
    --outdir results/cohort \
    -profile slurm,docker

# Overriding the default DB location
nextflow run runners/nextflow-runner/main.nf \
    --reads 'data/sample1/*_{1,2}.fq.gz' \
    --run_bakta true --bakta_db /data/bakta_db \
    -profile docker
```

`samples.csv` format: `sample_id,fastq_1,fastq_2` header row, one isolate per line.

**Containers**: `-profile docker`/`-profile singularity` only auto-mount host
paths that are declared Nextflow process inputs. `kraken2_db` is declared
this way and works out of the box. `bakta_db` and BUSCO's `--download_path`
are referenced directly via `params.*` inside the process script and are
**not** auto-mounted — either run with `-profile standard` (native execution,
no container), or extend `docker.runOptions` / add a Singularity bind mount
for `${projectDir}/../../assets` in `nextflow.config`.

## Pipeline Architecture — 5 phases

This runner mirrors the parent skill's 5-phase bettamt pattern exactly. Every sub-skill ships a bash recipe; the runner is a thin executor around it.

| Phase | Subworkflow             | Modules                                                                                  | Source bash recipe                            |
| ----- | ----------------------- | ---------------------------------------------------------------------------------------- | --------------------------------------------- |
| 0     | (PREFLIGHT process)     | `PREFLIGHT`, `KRAKEN2_READS` (opt-in)                                                    | `preflight/genome-input-preflight/SKILL.md`   |
| 1     | preflightToPolish       | `SPADES_ASSEMBLY` (short), `FLYE_ASSEMBLY` (long), `UNICYCLER_ASSEMBLY` (hybrid)         | `assembly/{short,long,hybrid}-assembly/SKILL.md` |
| 2     | preflightToPolish (cont)| `MEDAKA_POLISH` (long), `MAP_SHORT_READS` + `POLYPOLISH` (hybrid), `PYPOLCA_POLISH` opt. | `polishing/genome-polishing/SKILL.md`         |
| 3     | polishToQc              | `QUAST`, `BUSCO`, `CHECKM`                                                               | `validation/assembly-qc/SKILL.md`             |
| 4     | qcToAnnotation          | `BAKTA_ANNOTATE`                                                                         | `annotation/genome-annotation/SKILL.md`       |

The runner does NOT do the upstream read QC/trimming phase — that lives in the sister `read-qc-trimming` skill.

## Modules

Resource labels mirror nf-core convention:

| Module               | Label           | Container                                                             | Purpose                                |
| -------------------- | --------------- | --------------------------------------------------------------------- | -------------------------------------- |
| `PREFLIGHT`          | process_low     | `quay.io/biocontainers/seqkit:2.13.0`                                | Read stats + per-sample params.json    |
| `KRAKEN2_READS`      | process_medium  | `quay.io/biocontainers/kraken2:2.17.1`                               | Read-level contamination screen        |
| `SPADES_ASSEMBLY`    | process_high    | `quay.io/biocontainers/spades:3.15.5`                                | Short-read assembly (default mode=short)|
| `FLYE_ASSEMBLY`      | process_high    | `quay.io/biocontainers/flye:2.9.6`                                   | Long-read assembly (default mode=long) |
| `UNICYCLER_ASSEMBLY` | process_high    | `quay.io/biocontainers/unicycler:0.5.1`                              | Hybrid assembly (mode=hybrid)          |
| `MEDAKA_POLISH`      | process_medium  | `quay.io/biocontainers/medaka:2.2.2`                                 | ONT consensus polishing                |
| `MAP_SHORT_READS`    | process_medium  | `quay.io/biocontainers/pypolca:0.4.0` (bundles bwa + samtools)       | bwa-mem + samtools sort for polishing  |
| `POLYPOLISH`         | process_medium  | `quay.io/biocontainers/polypolish:0.7.1`                             | Short-read polishing (hybrid path)     |
| `PYPOLCA_POLISH`     | process_medium  | `quay.io/biocontainers/pypolca:0.4.0`                                 | Optional extra polish round            |
| `QUAST`              | process_low     | `quay.io/biocontainers/quast:5.3.0`                                  | Assembly continuity / N50 / length     |
| `BUSCO`              | process_high    | `quay.io/biocontainers/busco:6.1.0`                                  | Genome completeness                     |
| `CHECKM`             | process_high    | `quay.io/biocontainers/checkm-genome:1.2.5`                           | Marker-gene completeness / contamination|
| `BAKTA_ANNOTATE`     | process_medium  | `quay.io/biocontainers/bakta:1.12.1`                                 | Functional annotation                   |

All containers are pinned per nf-core style — no `:latest`.

## Subworkflows

| Subworkflow              | Phase boundaries covered          | take                          |
| ------------------------ | --------------------------------- | ----------------------------- |
| `preflightToPolish`      | Phase 0 → Phase 1 → Phase 2       | `reads_ch` (4-tuple sample_id, R1, R2, long_read) |
| `polishToQc`             | Phase 2 → Phase 3                 | `assembly_ch` (tuple sample_id, assembly)        |
| `qcToAnnotation`         | Phase 3 → Phase 4                 | `assembly_ch`                                  |

## Profiles

| Profile      | Executor        | Containers   | When                                                  |
| ------------ | --------------- | ------------ | ----------------------------------------------------- |
| `standard`   | local           | none         | Tools on `$PATH`; no containers                      |
| `docker`     | local           | Docker       | Default for desktop / single-node                   |
| `singularity`| local           | Singularity  | HPC environments where Docker is denied             |
| `slurm`      | SLURM           | from profile | HPC submission; combine with `singularity` or `docker` |
| `test`       | local (capped)  | none         | Sanity-check the DAG end-to-end; reads from `test_data/reads/` |

Combine profiles: `-profile slurm,singularity`, `-profile docker,test`.

## Sample Sheet

CSV with header `sample_id,fastq_1,fastq_2` and one row per isolate:

```csv
sample_id,fastq_1,fastq_2
sampleA,/data/sampleA_1.fq.gz,/data/sampleA_2.fq.gz
sampleB,/data/sampleB_1.fq.gz,/data/sampleB_2.fq.gz
```

For long-read mode, the sample sheet is not used; pass `--long_reads 'data/*.fq.gz'` instead.

## Resume and Caching

Nextflow's `-resume` flag is **strongly recommended** for the polishing & QC phases (BUSCO download is expensive, and any redo of `quast` after a tiny change is wasteful).

```bash
# First run (may take hours)
nextflow run main.nf --reads 'data/*_{1,2}.fq.gz' -profile docker

# Resume after fixing one parameter
nextflow run main.nf -resume -profile docker \
    --reads 'data/*_{1,2}.fq.gz' \
    --busco_lineage bacteria_odb12
```

Cache invalidation rules:

- Container change → all tasks re-run.
- Input file content change → only downstream tasks re-run.
- Config-only change → task hashes unchanged; `-resume` works.

**Cache directory cleanup**: by default under `$PWD/work/`. Use `nextflow clean -f work` to wipe; do this between sample sets to avoid stale state.

## Trace / Report / Timeline

Enabled by default in `nextflow.config`. Output paths:

```
${params.outdir}/
├── pipeline_info/
│   ├── execution_trace.txt
│   ├── execution_report.html
│   └── execution_timeline.html
├── preflight/
├── assembly/
├── polishing/
├── qc/
└── annotation/
```

Open `execution_report.html` in a browser for the per-task resource usage report.

## Resource Labels

nf-core convention (defined in `conf/base.config`):

| Label            | cpus | memory | time |
| ---------------- | ---- | ------ | ---- |
| `process_single` | 1    | 6 GB   | 4 h  |
| `process_low`    | 2    | 12 GB  | 4 h  |
| `process_medium` | 6    | 36 GB  | 8 h  |
| `process_high`   | 12   | 72 GB  | 16 h |
| `process_long`   | 1    | 6 GB   | 20 d |

Per-process overrides are in `conf/modules.config` (BAKTA is `process_medium`).

## Troubleshooting — Signature Library

| Symptom                                          | Likely cause                              | Fix                                                |
| ------------------------------------------------ | ----------------------------------------- | -------------------------------------------------- |
| `processExecutorNotPausedException`              | Insufficient memory for SPAdes            | Switch to `process_high` or reduce `--reads` set   |
| `Kraken2 DB not found`                           | `--kraken2_db` wrong path, or default `assets/kraken2_db` is empty | Confirm `params.kraken2_db` is the directory, not the `.k2d` file; populate `$SKILL_ROOT/assets/kraken2_db` with `kraken2-build` or pass `--kraken2_db /path/to/db` |
| Bakta exits early with `DatabaseNotFound`        | `--bakta_db` not supplied and default `assets/bakta_db` is empty | Run `bakta_db download -o "$SKILL_ROOT/assets/bakta_db"` once, or pass `--bakta_db /path/to/bakta-db`, or `--run_bakta false` |
| Flye `--nano-hq` flag rejected                    | Flye version < 2.9                        | Switch container tag (see `modules/long_read_assembly.nf` comment) |
| QUAST `report.html` empty                        | QUAST crashed on contig naming            | Verify sample id has no spaces / special chars     |
| BUSCO `Downloading lineage dataset` very slow    | Cold download to `assets/busco_downloads` | One-time cost; subsequent runs reuse the cache automatically via `--download_path`. To pre-warm it, run `busco --download_path "$SKILL_ROOT/assets/busco_downloads" --download ${params.busco_lineage}` ahead of time |
| CheckM `pkg_resources` ImportError               | Python ≥ 3.12 vs old setuptools           | Pre-set `PYTHONPATH` or use `singularity` profile  |
| Polypolish `polypolish polish` not found         | Container version mismatch                | Pin `polypolish:0.7.1` (current default)            |
| `-resume` re-runs everything                     | Out-dir has different paths               | Use the same `--outdir` and same `-work-dir`         |
| Empty `preflight.md` → runner halts              | PREFLIGHT stub-run when `-stub-run` flag  | Drop `-stub` for real run                          |

## Output Contract

Files the runner produces (under `--outdir`):

```
results/<sample_id>/
├── preflight/
│   └── <sample_id>_preflight.md          # per-sample audit
├── assembly/
│   └── spades/{<sample_id>_assembly.fasta, ...}
├── polishing/
│   ├── medaka/  OR
│   ├── polypolish/
│   └── pypolca/                          # only if --run_pypolca
├── qc/
│   ├── quast/<sample_id>_quast/
│   ├── busco/<sample_id>_busco/
│   └── checkm/<sample_id>_checkm/
├── annotation/
│   └── bakta/<sample_id>_bakta/<sample_id>.gff3
└── pipeline_info/
    ├── execution_trace.txt
    ├── execution_report.html
    └── execution_timeline.html
```

This is the same contract as the bash recipe — `validation/assembly-qc/SKILL.md` and `annotation/genome-annotation/SKILL.md` consume these files identically regardless of which executor produced them.

## Validation

Smoke test (no inputs needed; runs `-stub-run` style):

```bash
cd runners/nextflow-runner
nextflow run main.nf -profile test --stub-run
```

You should see a 5-step DAG print but no actual tool execution.

Full smoke test (needs real test data — small FASTQ pair):

```bash
mkdir -p test_data/reads/
# drop any two small FASTQ pairs in here
mv your_pair_1.fq.gz test_data/reads/sampleA_1.fastq.gz
mv your_pair_2.fq.gz test_data/reads/sampleA_2.fastq.gz

nextflow run main.nf -profile test --outdir test_results
```

## Cross-references

- **Parent skill**: [`bacterial-genome-analysis`](https://github.com/cheahhl814/bacterial-genome-analysis) — bash recipes live here
- **Upstream QC**: [`read-qc-trimming`](https://github.com/cheahhl814/read-qc-trimming) — read trimming before assembly
- **Sibling extension skills**:
  - [`amr-gene-screening`](https://github.com/cheahhl814/amr-gene-screening) — AMR + virulence screening (Phase 5b, standalone)
  - [`mobilome-profiling`](https://github.com/cheahhl814/mobilome-profiling) — plasmids + prophages + IS (Phase 5c, standalone)
  - [`typing-and-pangenome`](https://github.com/cheahhl814/typing-and-pangenome) — MLST/cgMLST + pangenome (Phase 5d/e, standalone; ships its own Nextflow runner)
- **Pattern**: [`BettaMt-agents`](https://github.com/cheahhl814/BettaMt-agents) — the `bettamt-preflight → bettamt-qc` pattern this skill adopts
- **Nextflow style**: [`nextflow-pipelines`](https://github.com/cheahhl814/nextflow-pipelines) — DSL2 + nf-core convention reference
- **Reference pipeline**: [`nf-core/bacass`](https://github.com/nf-core/bacass) — the gold-standard Nextflow pipeline this runner mirrors

## References

- Di Tommaso P, et al. 2017. Nextflow enables reproducible computational workflows. *Nat Biotechnol* 35:316. doi:10.1038/nbt.3820
- Ewels PA, et al. 2020. The nf-core framework for community-curated bioinformatics pipelines. *Nat Biotechnol* 38:276.
- Chen Z, et al. 2024. nf-core/bacass: a comprehensive pipeline for bacterial genome assembly and annotation. doi:10.5281/zenodo.10392695
- Antipov D, et al. 2016. hybridSPAdes: an algorithm for hybrid assembly of short and long reads. *Bioinformatics* 32:3349.
- Wick RR, et al. 2017. Unicycler: Resolving bacterial genome assemblies from short and long sequencing reads using a de Bruijn graph. *PLoS Comput Biol* 13:e1005595.
- Kolmogorov M, et al. 2019. Assembly of long, error-prone reads using repeat graphs. *Nat Biotechnol* 37:540. (Flye)
- Wick RR, Holt KE. 2022. Polypolish: Short-read polishing of long-read assemblies. *PLoS Comput Biol* 18:e1009802.
- Mikheenko A, et al. 2018. Versatile genome assembly evaluation with QUAST-LG. *Bioinformatics* 34:i142.
- Simão FA, et al. 2015. BUSCO: assessing genome assembly and annotation completeness with single-copy orthologs. *Bioinformatics* 31:3210.
- Parks DH, et al. 2015. CheckM: assessing the quality of microbial genomes recovered from isolates, single cells, and metagenomes. *Genome Res* 25:1043.
- Schwengers O, et al. 2021. Bakta: rapid and standardized annotation of bacterial genomes via alignment-free sequence identification. *Bioinformatics* 37:4446. (Bakta; was Bakta v1.x at this runner's release)
- Nextflow DSL2 docs. https://www.nextflow.io/docs/latest/dsl2.html
- nf-core style guide. https://nf-co.re/docs/contributing/guidelines
