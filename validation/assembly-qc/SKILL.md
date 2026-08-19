---
name: assembly-qc
description: Quantify the quality, completeness, and contamination of a bacterial genome assembly AND write a pass/warn/fail report.md. This skill ensures that an assembly is "finished" enough for downstream annotation and comparative genomics using CheckM, QUAST, BUSCO, and Kraken2. Always run after polishing.
version: 5
updated: "2026-08-14"
triggers:
  - "validate assembly"
  - "check assembly quality"
  - "QUAST"
  - "CheckM"
  - "BUSCO"
  - "Kraken2"
  - "genome completeness"
  - "assembly contamination"
  - "is my bacterial genome ready"
  - "bacterial genome QC report"
---

# Skill: assembly-qc

> **v5 redesign.** This skill used to be just a recipe for running QC tools. It now also **generates a verdict** by writing `$RUN_DIR/report.md` with pass/warn/fail verdicts, evidence, and a reproducibility footer. The 4 tools (`QUAST`, `CheckM`, `BUSCO`, `Kraken2`) are unchanged.

## Audience

This skill serves two purposes:
- **AI Agents**: Triggered by phrases like *"validate assembly"* or *"is my bacterial genome ready"*. Must run all four QC tools and write `report.md`. The MIMAG Go/No-Go gate determines the verdict.
- **Human Users**: Provides conceptual background, decision rationale, and troubleshooting guidance.

## When to Use This Skill

Use this skill if:
- You have a **polished or unpolished** assembly that needs validation.
- You want to determine if the assembly meets **MIMAG high-quality standards** ($>95\%$ completeness, $<5\%$ contamination).
- You suspect **contamination** or **fragmentation** in your assembly.
- You need to compare multiple assemblies (e.g., from different assemblers).

Do NOT use this skill if:
- You only have raw reads (use `read-qc-trimming` first).
- You are working with metagenomic data (different QC paradigms apply; use MetaQUAST and MAG-specific tools).

## 0. Inputs / Outputs contract

This sub-skill **refuses to run** unless the upstream artifacts are present.

### Inputs (consumed)
| Path | Source | Required? |
| --- | --- | --- |
| `$RUN_DIR/assembly.fasta` | `polishing/genome-polishing` (or `assembly/*` for skip-polish) | yes |

### Outputs (produced)
| Path | Owner | Format | Notes |
| --- | --- | --- | --- |
| `$RUN_DIR/report.md` | this skill | Markdown | **The QC verdict document.** Pass/warn/fail table + evidence + reproducibility footer. |
| `$RUN_DIR/quast_output/report.html` | `QUAST` | HTML | Structural metrics, archival. |
| `$RUN_DIR/checkm_output/` | `CheckM` | TSV + tree | Completeness/contamination, archival. |
| `$RUN_DIR/busco_output/` | `BUSCO` | TSV + plots | Evolutionary completeness, archival. |
| `$RUN_DIR/kraken2_report.txt` | `Kraken2` | TSV | Contamination screen. |

### Where to write
- Use `$RUN_DIR` (env var) or the current working directory if `$RUN_DIR` is unset.
- All output files live next to `$RUN_DIR/assembly.fasta` so the report is co-located with the assembly it describes.

## Description

Assembly quality control (QC) prevents the use of fragmented or contaminated genomes in downstream analysis. This skill transforms a FASTA assembly into a set of quantitative metrics (Completeness, Contamination, Contiguity) **and a single `report.md` you can show your PI / collaborator / reviewer**. It is the **last step before annotation** — annotation on a broken assembly is wasted compute.

## Conceptual Background

**The Three Pillars of Assembly Quality:**

1. **Contiguity** (QUAST): Is the assembly in few, long contigs? Measured by N50, L50, and total contig count.
2. **Completeness** (CheckM, BUSCO): Does the assembly contain all expected genes? Measured by the presence of lineage-specific single-copy markers.
3. **Contamination** (Kraken2): Does the assembly contain sequences from other organisms? Measured by taxonomic classification of contigs.

**Why are these metrics important?** An assembly with low completeness will miss real genes, leading to false-negative annotations. An assembly with high contamination will produce false-positive annotations from other organisms.

## Prerequisites

- **Environment**: Active environment with required tools.
- **Upstream Evidence**: A polished assembly (`$RUN_DIR/assembly.fasta`) from `polishing/genome-polishing` or an assembly skill (skip-polish mode).
- **Required Tools**:
  - `QUAST` (Structural contiguity).
  - `CheckM` (Lineage-based completeness/contamination).
  - `BUSCO` (Ortholog-based completeness).
  - `Kraken2` (Taxonomic contamination check).

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add quast checkm-genome busco kraken2
```

## Procedure

The procedure has **two phases**: (1) run the four QC tools and collect raw metrics, (2) write `report.md` with verdicts.

### Phase 1: Run QC tools

#### 1. Structural Analysis (`QUAST`)

QUAST provides the "physical" metrics of the assembly.

```bash
mkdir -p "$RUN_DIR/quast_output"
quast.py "$RUN_DIR/assembly.fasta" -o "$RUN_DIR/quast_output/" --threads 8
```
*Key Metrics (read from `$RUN_DIR/quast_output/report.txt`):*
- **N50**: Half the assembly is in contigs of this length or longer.
- **Total Length**: Should match expected genome size.
- **Number of Contigs**: Lower is better; 1 for a closed genome.
- **L50**: Number of contigs covering 50\% of the genome.

#### 2. Biological Validation (`CheckM`)

CheckM is the gold standard for bacterial genomics. It uses lineage-specific single-copy genes to estimate completeness and contamination.

```bash
# 1. Place assembly in a directory
mkdir -p "$RUN_DIR/checkm_input"
cp "$RUN_DIR/assembly.fasta" "$RUN_DIR/checkm_input/"

# 2. Run CheckM lineage workflow
checkm lineage_wf -t 8 -x fa "$RUN_DIR/checkm_input/" "$RUN_DIR/checkm_output/"

# 3. Summarize results
checkm qa "$RUN_DIR/checkm_output/lineage.ms" "$RUN_DIR/checkm_output/" -o 1 > "$RUN_DIR/checkm_output/qa.txt"
```

*Acceptance Criteria (MIMAG standards):*
- **Completeness**: $> 95\%$ (for high-quality isolates).
- **Contamination**: $< 5\%$.

#### 3. Evolutionary Completeness (`BUSCO`)

BUSCO verifies that the assembly contains the expected universal genes for the chosen lineage.

```bash
mkdir -p "$RUN_DIR/busco_output"
busco -i "$RUN_DIR/assembly.fasta" \
      -l bacteria_odb10 \
      -o "$RUN_DIR/busco_output/busco" \
      -m genome \
      --cpu 8 \
      --download_path "$SKILL_ROOT/assets/busco_downloads"
```

Point `--download_path` at `$SKILL_ROOT/assets/busco_downloads` (not a per-run directory) so the lineage dataset is downloaded once and reused by every future run instead of being re-fetched per `$RUN_DIR`.
*Key Metrics (read from `$RUN_DIR/busco_output/short_summary.*.txt`):*
- **Complete BUSCOs (C)**: Ideally $> 95\%$.
- **Fragmented (F)**: Ideally $< 5\%$.
- **Missing (M)**: Ideally $< 5\%$.

#### 4. Contamination Check (`Kraken2`)

Ensure the assembly does not contain sequences from unexpected organisms.

```bash
kraken2 --db "${KRAKEN2_DB_PATH:-$SKILL_ROOT/assets/kraken2_db}" \
        --threads 8 \
        --output "$RUN_DIR/kraken2.out" \
        --report "$RUN_DIR/kraken2_report.txt" \
        --confidence 0.05 \
        "$RUN_DIR/assembly.fasta"
```
*Action*: Any contig assigned to a different taxonomic class (e.g., human, plant, or different bacteria) should be flagged for removal.

*DB reuse*: if `$KRAKEN2_DB_PATH` is unset, this defaults to `$SKILL_ROOT/assets/kraken2_db` — build or extract the DB there once (`kraken2-build --db "$SKILL_ROOT/assets/kraken2_db" ...`) and every future run reuses it without re-downloading.

### Phase 2: Write `report.md`

After all four tools complete, write `$RUN_DIR/report.md` from the **§Output contract template** below. **Never** skip this — the user wants a single document with verdicts, not four separate logs.

The verdict assignment per check:

| Check | PASS condition | WARN condition | FAIL condition |
| --- | --- | --- | --- |
| **Completeness (CheckM)** | $> 95\%$ | $90{-}95\%$ | $< 90\%$ |
| **Contamination (CheckM)** | $< 5\%$ | $5{-}10\%$ | $> 10\%$ |
| **N50 (QUAST)** | $> 50,000$ bp | $10,000{-}50,000$ bp | $< 10,000$ bp |
| **Contig count** | $1$ (closed) | $2{-}50$ | $> 50$ |
| **BUSCO complete** | $> 95\%$ | $80{-}95\%$ | $< 80\%$ |
| **BUSCO fragmented** | $< 5\%$ | $5{-}10\%$ | $> 10\%$ |
| **Kraken2 contamination** | $\le 5\%$ contigs off-genus | $5{-}10\%$ | $> 10\%$ (or any off-class) |

**Overall verdict:**
- **PASS**: all checks PASS.
- **PASS-WITH-WARNINGS**: no FAIL, at least one WARN.
- **FAIL**: any check FAIL.

## Interpretation Guidelines

| Symptom | Inference | Action |
| :--- | :--- | :--- |
| **Low Completeness** | Incomplete sequencing or failed assembly. | Re-evaluate assembly parameters or increase coverage. |
| **High Contamination** | Mixed culture or assembly artifacts. | Use `Kraken2` to identify contaminating contigs; filter. |
| **Low N50 / Many Contigs** | Fragmented assembly. | Try hybrid assembly or use `Autocycler` for consensus. |
| **High Missing BUSCOs** | Incomplete capture of conserved genes. | Check sequencing depth; consider repeat resolution tools. |

## Troubleshooting — Signature library

| Signature in stderr / log | Likely cause | Suggested fix |
| --- | --- | --- |
| `CheckM: ModuleNotFoundError: No module named 'pkg_resources'` | Python $\ge 3.12$ + setuptools $\ge 81$ removed `pkg_resources` | Pin `setuptools < 81` in pixi.toml (verified 2026-08-14 — the current skill's pixi.toml already does this). |
| CheckM fails to place assembly in a lineage | Novel organism or highly contaminated assembly | Use `--reduced_tree` flag; manually specify lineage with `--taxon_list`. |
| CheckM reports very high contamination ($>10\%$) | Multiple organisms in the assembly | Identify and remove contaminating contigs using `Kraken2`. |
| `BUSCO database download fails` | Network issues or server unavailability | Retry; use `busco --download_path` to specify a local mirror. |
| `QUAST reports very high misassembly count` | Repetitive genome or incorrect assembler parameters | Try a different assembler; verify with read mapping. |
| `Kraken2 database too large to download` | Limited disk space | Use a smaller database (e.g. `minikraken2`) or `centrifuge` instead. |
| `quast.py: command not found` | pixi env missing `quast` | `pixi add quast`. |
| `checkm: command not found` | pixi env missing `checkm-genome` | `pixi add checkm-genome`. |
| `busco: command not found` | pixi env missing `busco` | `pixi add busco`. |
| `kraken2: command not found` | pixi env missing `kraken2` | `pixi add kraken2`. |
| `Killed` (any tool, exit 137) | OOM | Reduce `-t` (threads); for CheckM, see pixi.toml `setuptools<81` note. |
| `Kraken2: database not found` | `KRAKEN2_DB_PATH` unset or path wrong | `export KRAKEN2_DB_PATH="$SKILL_ROOT/assets/kraken2_db"` (or another path). |

## Output contract — `$RUN_DIR/report.md` template

**Always** write to `$RUN_DIR/report.md`. Template:

```markdown
# Bacterial genome assembly QC report

Sample:     <sample_id>
Pipeline:   bacterial-genome-analysis v5
Assembly:   $RUN_DIR/assembly.fasta
Generated:  <ISO8601>

## Verdict summary

| Check                  | Result      | Notes                                          |
|------------------------|-------------|------------------------------------------------|
| Completeness (CheckM)  | ✅ / ⚠️ / ❌ | <X>% (target > 95%)                            |
| Contamination (CheckM) | ✅ / ⚠️ / ❌ | <X>% (target < 5%)                             |
| N50 (QUAST)            | ✅ / ⚠️ / ❌ | <X> bp (target > 50,000)                       |
| Contig count (QUAST)   | ✅ / ⚠️ / ❌ | <N> (target 1 for closed)                      |
| Total length (QUAST)   | ✅ / ⚠️ / ❌ | <X> bp                                         |
| BUSCO complete         | ✅ / ⚠️ / ❌ | <X>% (target > 95%)                            |
| BUSCO fragmented       | ✅ / ⚠️ / ❌ | <X>% (target < 5%)                             |
| BUSCO missing          | ✅ / ⚠️ / ❌ | <X>% (target < 5%)                             |
| Kraken2 contamination  | ✅ / ⚠️ / ❌ | <X>% off-genus (target ≤ 5%)                   |

**Overall**: <PASS / PASS-WITH-WARNINGS / FAIL>

## Evidence

### Completeness & Contamination (CheckM)
\`\`\`
<raw `checkm qa` output, or parsed columns>
\`\`\`

### Structural metrics (QUAST)
\`\`\`
<raw QUAST report.txt, summary section>
\`\`\`

### Evolutionary completeness (BUSCO)
\`\`\`
<raw BUSCO short_summary, key numbers: C / F / M / n>
\`\`\`

### Taxonomic contamination (Kraken2)
\`\`\`
<top 10 rows of kraken2_report.txt, or note "no off-genus hits">
\`\`\`

## Notes & recommended follow-ups
- <bullet list of any warnings or failures, with concrete next steps>
- <e.g. "Completeness 87% — recommend re-assembly with higher coverage or hybrid mode">

## Reproducibility
- assembly:  $RUN_DIR/assembly.fasta (sha256: <hash>)
- pipeline:  bacterial-genome-analysis v5 (commit <hash if available>)
- pixi.lock: $RUN_DIR/pixi.lock (if used)
- this report: $RUN_DIR/report.md (regenerable via this skill)
```

The agent **must** populate every field with the actual measured values from Phase 1. Don't leave placeholder text.

## Verification

- [ ] `$RUN_DIR/report.md` exists.
- [ ] All four QC tools ran without error.
- [ ] Overall verdict is `PASS` or `PASS-WITH-WARNINGS` before annotation.
- [ ] Reproducibility footer includes assembly sha256.

## What NOT to do

- Do **not** run annotation on a `FAIL` verdict assembly. Annotation on a broken assembly is wasted compute.
- Do **not** skip writing `report.md`. The whole point of this skill is the single-document verdict.
- Do **not** ignore the 90/10 early-warning thresholds in the orchestrator (`SKILL.md` §D). Cross 90/10 and the orchestrator will refuse to proceed to annotation.
- Do **not** use `--reduced_tree` in CheckM unless you've checked the assembly is genuinely novel — for routine isolates the default tree works.
- Do **not** compare Kraken2 results across databases. Different DB versions give different "genus" calls; stick to one DB version for the project.
- Do **not** write `report.md` to a tool-default path. Always end with `$RUN_DIR/report.md` — that is the path the orchestrator (`SKILL.md` §0.2 stage detection) reads.

## Handoff

After this skill writes `$RUN_DIR/report.md`:

- **If `report.md` overall is `PASS`** → hand off to `annotation/genome-annotation` for functional labeling.
- **If `PASS-WITH-WARNINGS`** → surface the warnings to the user, ask whether to proceed to annotation. The MIMAG thresholds ($>95\%$ completeness, $<5\%$ contamination) are met, but other warnings (high contig count, off-genus Kraken2 hits) deserve a second look.
- **If `FAIL`** → recommend going back to `polishing/genome-polishing` (over-polishing regression) or `assembly/*` (re-assembly with different parameters or higher coverage). Do **not** proceed to annotation.

Say: *"QC report written to `$RUN_DIR/report.md`. Overall verdict: `<verdict>`. <1-line summary>. Handing off to `<next-skill>`."*
