---
name: genome-annotation
description: Assign biological functions to the features of a bacterial genome assembly. This skill transforms a validated FASTA assembly into a set of standard annotation files (GFF, GBK, FAA), supporting modern tools like Bakta and DFAST. Always run after assembly-qc reports PASS. Has explicit ask-user stop points (SP18, SP19) that fire only when evidence is ambiguous.
version: 5.0.2
updated: "2026-08-14"
triggers:
  - "annotate genome"
  - "find genes in assembly"
  - "Bakta"
  - "Prokka"
  - "DFAST"
  - "bacterial annotation"
  - "gene prediction"
---

# Skill: genome-annotation

## Audience

This skill serves two purposes:

- **AI Agents**: Triggered by phrases like *"annotate genome"* or *"find genes in assembly"*. Must confirm `$RUN_DIR/report.md` overall verdict is `PASS` before proceeding.
- **Human Users**: Provides conceptual background, decision rationale, and troubleshooting guidance.

## When to Use This Skill

Use this skill if:

- You have a **validated, polished assembly** (i.e. `$RUN_DIR/report.md` overall verdict is `PASS` or `PASS-WITH-WARNINGS`).
- You need to identify **protein-coding genes**, **rRNAs**, **tRNAs**, or **regulatory elements**.
- You are preparing a genome for **NCBI submission** (requires GenBank-format annotation).
- You need input for downstream analyses (e.g., pangenome analysis with Roary, AMR gene detection).

Do NOT use this skill if:

- Your assembly has **not passed QC** (`$RUN_DIR/report.md` is missing or `FAIL`). Annotation will produce false results.
- You are working with **eukaryotic** genomes (different tools and paradigms apply).
- You only need **read-level** functional annotation (use a read-mapping approach instead).

## 0. Inputs / Outputs contract

This sub-skill **refuses to run** unless the upstream artifacts are present AND the QC verdict is at least PASS-WITH-WARNINGS.

### Inputs (consumed)

| Path                      | Source                       | Required?                                  |
| ------------------------- | ---------------------------- | ------------------------------------------ |
| `$RUN_DIR/assembly.fasta` | `polishing/genome-polishing` | yes                                        |
| `$RUN_DIR/report.md`      | `validation/assembly-qc`     | yes (must show PASS or PASS-WITH-WARNINGS) |

### Outputs (produced)

| Path                                  | Owner                 | Format            | Notes                                                                                               |
| ------------------------------------- | --------------------- | ----------------- | --------------------------------------------------------------------------------------------------- |
| `$RUN_DIR/bakta_output/<prefix>.gff3` | `Bakta`               | GFF3              | Standard feature coordinates.                                                                       |
| `$RUN_DIR/bakta_output/<prefix>.gbff` | `Bakta`               | GenBank flat file | NCBI-submission-ready.                                                                              |
| `$RUN_DIR/bakta_output/<prefix>.faa`  | `Bakta`               | FASTA amino acid  | Protein sequences.                                                                                  |
| `$RUN_DIR/bakta_output/<prefix>.fna`  | `Bakta`               | FASTA nucleotide  | Coding sequences.                                                                                   |
| `$RUN_DIR/bakta_output/<prefix>.json` | `Bakta`               | JSON              | Machine-readable annotation.                                                                        |
| `$RUN_DIR/annotation-report.md`       | this skill (optional) | Markdown          | Annotation QC verdict, mirrors `report.md` style. **Only written if `--annotate-qc` is requested.** |

### Where to write

- Use `$RUN_DIR` (env var) or the current working directory if `$RUN_DIR` is unset.
- Annotation outputs go in a subdirectory `$RUN_DIR/bakta_output/` (or `prokka_output/`, etc.) — not directly in `$RUN_DIR/`, because each tool emits ~10 files.

## 0.5 Ask-User Stop Points

This sub-skill has **2 stop points** (SP18, SP19). Each fires only when the evidence is ambiguous. If the evidence is unambiguous, the agent auto-picks the default and proceeds silently.

### SP18 — Bakta DB not installed

| Trigger                                                                                        | Evidence check                            | Action                                                                                                                                                                                                                             |
| ---------------------------------------------------------------------------------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `$BAKTA_DB` env var unset AND no `bakta_db/` directory found AND `$SKILL_ROOT/assets/bakta_db/` is empty AND no `--db` flag in params.json | Bakta requires a ~10 GB database download | Ask: "Bakta database is not installed. Pick: (A) download now to `$SKILL_ROOT/assets/bakta_db` (~10 GB, one-time, reused by every future run), (B) use DFAST instead (lighter, ~2 GB DB, less comprehensive), (C) use Prokka (legacy, ships with small DB, less accurate for sORFs), (D) abort" |

**Auto-pick when**: `$BAKTA_DB` is set, OR `$SKILL_ROOT/assets/bakta_db/` already contains a populated database (auto-set `BAKTA_DB="$SKILL_ROOT/assets/bakta_db"`), OR user explicitly said "Bakta is configured". No ask.

### SP19 — NCBI submission intent detected

| Trigger                                                                                           | Evidence check                                                                  | Action                                                                                                                                                                                                                                                                       |
| ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User mentioned "NCBI submission", "GenBank submission", "BioSample", or "BioProject" in the brief | PGAP is required for NCBI submissions; Bakta + tbl2asn is a lighter alternative | Ask: "Detected NCBI submission intent. Pick: (A) use PGAP (official NCBI pipeline; heavyweight, requires metadata files), (B) use Bakta + tbl2asn (lighter, produces submission-ready .sqn file), (C) use Bakta only (not submission-ready; you'd convert later), (D) abort" |

**Auto-pick when**: no submission intent mentioned. Default to Bakta (Path A).

## Description

Genome annotation identifies protein-coding sequences (CDS), RNAs, and other genomic features, assigning them names and functions based on homology and ab initio prediction. This skill transforms a validated assembly into standard bioinformatics files.

## Conceptual Background

**The Three Layers of Annotation:**

1. **Ab Initio Gene Prediction**: Tools identify coding regions based on statistical models (e.g., Prodigal, GeneMark).
2. **Homology-Based Annotation**: Predicted genes are compared to reference databases (e.g., UniRef, RefSeq) to assign functions.
3. **Feature Detection**: Specialized tools identify specific features (e.g., ARAGORN for tRNAs, Infernal for rRNAs).

**Why Bakta over Prokka?**

- Bakta uses the entire **UniRef** protein database (taxonomy-independent).
- Bakta captures **sORFs** (small open reading frames) that Prokka misses.
- Bakta produces **dbxref-rich** annotations for better interoperability.
- Prokka's maintenance has slowed, while Bakta is actively developed.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**:
  - A validated, polished assembly (`$RUN_DIR/assembly.fasta`).
  - `$RUN_DIR/report.md` with overall verdict $\ge$ PASS-WITH-WARNINGS.
- **Required Tools**:
  - `Bakta` (Modern annotation, recommended).
  - `Prokka` (Legacy fast annotation).
  - `DFAST` (Alternative annotation).
  - `tbl2asn` (For GenBank submission).
  - `PGAP` (NCBI official; only if `--pgap` is requested — heavyweight).

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add bakta prokka dfast tbl2asn
# Bakta database download (one-time, ~10 GB) — target the skill's reusable
# cache so every future run (bash or Nextflow) picks it up automatically.
bakta_db download -o "$SKILL_ROOT/assets/bakta_db"
export BAKTA_DB="$SKILL_ROOT/assets/bakta_db"
```

## Procedure

### 0. Verify QC verdict

```bash
test -f "$RUN_DIR/report.md" || { echo "No report.md — run validation/assembly-qc first"; exit 1; }
OVERALL=$(grep -oP 'Overall\*\*:\s*\K[A-Z\-]+' "$RUN_DIR/report.md" || echo "UNKNOWN")
case "$OVERALL" in
  PASS|PASS-WITH-WARNINGS) echo "QC verdict: $OVERALL — proceeding" ;;
  FAIL|UNKNOWN) echo "QC verdict: $OVERALL — refusing to annotate. Fix assembly first."; exit 1 ;;
esac
```

**Do not annotate on a `FAIL` assembly.**

### 1. Tool Selection

| Goal                             | Recommended Tool | Why This Tool?                                                                                                    |
|:-------------------------------- |:---------------- |:----------------------------------------------------------------------------------------------------------------- |
| **Standard / High Quality**      | `Bakta`          | Next-gen replacement for Prokka. Uses UniRef database (taxonomy-independent), captures sORFs, dbxref-rich output. |
| **Fast / Legacy**                | `Prokka`         | Extremely fast; standard output; widely used. Useful for quick annotations or legacy compatibility.               |
| **Specialized (DFAST features)** | `DFAST`          | Lightweight; good for specific taxonomy; used in nf-core/bacass.                                                  |
| **Submission Grade**             | `PGAP`           | Required for NCBI/GenBank. Most authoritative; combines ab initio prediction with homology.                       |

### 2. Execution

#### Path A: Bakta (Recommended)

Bakta uses a comprehensive UniRef-based database for superior functional annotation.

```bash
mkdir -p "$RUN_DIR/bakta_output"

bakta --db "$BAKTA_DB" \
      --threads 8 \
      --output "$RUN_DIR/bakta_output/" \
      --prefix sample1 \
      "$RUN_DIR/assembly.fasta"
```

*Key Outputs:*

- `$RUN_DIR/bakta_output/sample1.gff3`: General Feature Format.
- `$RUN_DIR/bakta_output/sample1.gbff`: GenBank Flat File.
- `$RUN_DIR/bakta_output/sample1.faa`: FASTA Amino Acid (proteins).
- `$RUN_DIR/bakta_output/sample1.fna`: FASTA Nucleotide (CDSs).
- `$RUN_DIR/bakta_output/sample1.json`: Machine-readable annotation.

#### Path B: Prokka

```bash
mkdir -p "$RUN_DIR/prokka_output"
prokka --outdir "$RUN_DIR/prokka_output" \
       --prefix sample1 \
       --cpus 8 \
       --genus Escherichia \
       --species coli \
       "$RUN_DIR/assembly.fasta"
```

*Note: Providing `--genus` and `--species` significantly speeds up Prokka.*

#### Path C: DFAST

```bash
mkdir -p "$RUN_DIR/dfast_output"
dfast --genome "$RUN_DIR/assembly.fasta" \
      --output "$RUN_DIR/dfast_output" \
      --database dfast_db \
      --cpu 8
```

#### Path D: PGAP (NCBI Submission)

```bash
# PGAP runs as a Docker container; invoke via the official NCBI wrapper
pgap.py --help  # see PGAP docs for submission prep
# Output goes to PGAP's own directory; the user submits via the NCBI portal.
```

### 3. Output Files

The agent shall ensure the following files are produced:

- **`.gff`/`.gff3`**: General Feature Format (coordinates and types).
- **`.gbk`/`.gbff`**: GenBank format (full annotations including sequence).
- **`.faa`**: FASTA Amino Acid (protein sequences).
- **`.fna`**: FASTA Nucleotide (coding sequences).

## Interpretation Guidelines

- **Gene Density**: Check for gaps in annotation. Unusually large non-coding regions may indicate assembly errors or actual biological features (e.g., large plasmids, prophages).
- **Consistency**: Compare `Bakta` and `Prokka` results for critical genes (e.g., AMR genes) if the biological question is high-stakes.
- **Hypothetical Proteins**: A high percentage is expected, but if $>50\%$ of genes are hypothetical, consider re-annotation with `Bakta` or `PGAP`.

## Troubleshooting — Signature library

| Signature in stderr / log                    | Likely cause                               | Suggested fix                                                                                         |
| -------------------------------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| Bakta database download fails                | Network issues or disk space               | Retry with `--debug`; ensure sufficient disk space ($>10$ GB).                                        |
| `BAKTA_DB environment variable not set`      | DB path env var missing                    | `export BAKTA_DB="$SKILL_ROOT/assets/bakta_db"` (or another path) or pass `--db /path/to/db`.         |
| Annotation produces very few genes ($<1000$) | Assembly is incomplete or contaminated     | Re-check QC metrics in `$RUN_DIR/report.md`; ensure assembly passed completeness/contamination gates. |
| Annotation produces too many genes ($>8000$) | Contamination or fragmented assembly       | Run `Kraken2` to check for contamination; consider re-assembly.                                       |
| Prokka fails with "can't find genus"         | No taxonomy specified for novel organism   | Provide `--genus` and `--species` flags; or use `--metagenome` mode.                                  |
| `tbl2asn: command not found`                 | pixi env missing `tbl2asn`                 | `pixi add tbl2asn`.                                                                                   |
| `PGAP submission fails`                      | Missing metadata or incorrect file formats | Verify input formats; check PGAP documentation for required fields.                                   |
| `bakta: command not found`                   | pixi env missing `bakta`                   | `pixi add bakta`.                                                                                     |
| `prokka: command not found`                  | pixi env missing `prokka`                  | `pixi add prokka`.                                                                                    |
| `dfast: command not found`                   | pixi env missing `dfast`                   | `pixi add dfast`.                                                                                     |
| `Killed` (any tool, exit 137)                | OOM                                        | Reduce `--threads`; Bakta is the heaviest.                                                            |
| Annotation produces no tRNAs                 | `BAKTA_DB` is missing the tRNA models      | Re-download full Bakta DB (not just the protein subset).                                              |

## Verification

- [ ] `$RUN_DIR/report.md` exists and overall verdict is $\ge$ PASS-WITH-WARNINGS.
- [ ] `.gff` and `.gbk` files exist in `$RUN_DIR/bakta_output/`.
- [ ] Total number of predicted genes is reasonable for the target species (e.g., $\approx 3\text{-}5$ Mbp $\rightarrow$ $3000\text{-}5000$ genes).
- [ ] The annotation is compatible with downstream tools (e.g., Roary, Panaroo).
- [ ] For NCBI submission, `.sqn` file generated via `tbl2asn`.

## Output contract

This skill produces:

- Standard annotation files in `$RUN_DIR/<tool>_output/<prefix>.{gff3,gbff,faa,fna,json}`.
- **Optional** `$RUN_DIR/annotation-report.md` (only if the user requests annotation QC, mirroring `bettamt-annotate-qc` style). For v5, this is **off by default** — write only on explicit request.

It does **not** produce a top-level `report.md` — that's `validation/assembly-qc`'s job.

## What NOT to do

- Do **not** annotate on a `FAIL` assembly. Annotation on a broken assembly is wasted compute and produces misleading downstream results.
- Do **not** skip the `$RUN_DIR/report.md` check in step 0. Always verify QC passed first.
- Do **not** re-annotate an assembly that's already annotated without first checking the existing annotation — Bakta/Prokka runs are not idempotent and you can produce inconsistent results.
- Do **not** mix annotation tools' outputs. Pick one (Bakta recommended) and use it for the whole project; mixing produces inconsistent gene naming.
- Do **not** annotate eukaryotic data with this skill — Bakta's models are bacterial-only.
- Do **not** submit to NCBI via `PGAP` without first reading the PGAP documentation — `PGAP` is heavyweight, requires metadata files, and has its own validation pipeline.

## Handoff

After this skill writes the annotation files into `$RUN_DIR/bakta_output/`:

- The user can now use the `.gff3`, `.gbff`, `.faa` files in downstream tools (Roary, Panaroo, ABRicate, etc.).
- If the user wants annotation QC, write `$RUN_DIR/annotation-report.md` using the BettaMt-style pass/warn/fail template (gene count, gene names, length sanity, D-loop if applicable).
- This is the **terminal phase** — there is no further skill to invoke.

Say: *"Annotation written to `$RUN_DIR/bakta_output/<prefix>.{gff3,gbff,faa,fna}`. <N> genes annotated. <N> CDS, <N> tRNA, <N> rRNA. Pipeline complete."*
