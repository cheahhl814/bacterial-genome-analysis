# assets/ — reusable database cache

This folder is the default download target for the large reference databases
used by the bacterial-genome-analysis skills. Populate it once; every
subsequent run (bash sub-skills and the Nextflow runner alike) reuses it
without re-downloading.

| Subfolder | Tool | Populated by |
|---|---|---|
| `bakta_db/` | Bakta (annotation) | `bakta_db download -o assets/bakta_db` |
| `kraken2_db/` | Kraken2 (contamination QC) | `kraken2-build --db assets/kraken2_db ...` (or a pre-built DB extracted here) |
| `busco_downloads/` | BUSCO (assembly QC) | `busco --download_path assets/busco_downloads ...` (auto-populated on first run) |

**Not committed to git.** These databases range from hundreds of MB to
10+ GB — only this README is tracked; everything else under `assets/` is
git-ignored (see the repo `.gitignore`).

**Nextflow runner**: `runners/nextflow-runner/nextflow.config` defaults
`bakta_db`, `kraken2_db`, and `busco_download_path` to these folders
(`${projectDir}/../../assets/...`), so a database downloaded via a bash
sub-skill run is picked up automatically by the pipeline with no extra flags.

**Containers**: if running the Nextflow runner with `-profile docker` or
`-profile singularity`, these host paths are not auto-mounted into the
container (they're referenced via `params.*`, not declared as Nextflow
process inputs). See the troubleshooting sections in
`runners/nextflow-runner/SKILL.md` for the volume-mount workaround.
