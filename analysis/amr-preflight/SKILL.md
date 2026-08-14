---
name: amr-preflight
description: Validate a bacterial genome assembly for AMR gene screening and write amr_params.json + amr_preflight.md. Computes evidence (assembly contiguity, taxonomy, plasmid evidence, AMRFinderPlus DB presence) and emits a GO / GO-WITH-WARNINGS / NO-GO verdict. Always run after annotation and before amr-screening. Has 4 explicit ask-user stop points (SP20–SP23) that fire only when evidence is ambiguous. Triggers: "amr preflight", "validate assembly for amr screening", "check amr inputs", "amr params".
version: 5.1.0
updated: "2026-08-14"
triggers:
  - "amr preflight"
  - "validate for amr screening"
  - "check amr inputs"
---

# amr-preflight — Phase 5a.0 input validation

## Audience

Bioinformaticians preparing a bacterial genome for clinical or surveillance
AMR gene screening. Pairs with the v5.0.2 `bacterial-genome-analysis`
orchestrator; sits after Phase 4 (annotation) and before the
`amr-screening` sub-skill.

## When to Use This Skill

Use this sub-skill **every time** before running `amr-screening`. It validates
that the assembly is intact, picks the right AMR tool combination, decides
whether to search for point mutations, and writes `amr_params.json` (the machine
contract) and `amr_preflight.md` (the audit trail) with an overall verdict.

If the user already has `amr_params.json` from a previous preflight run, do not
re-run — the `amr-screening` sub-skill will refuse to run if preflight evidence
is missing.

## 0. Inputs / Outputs contract

### Inputs (the sub-skill refuses to run without these)

| Variable / file | Source | Required? |
| --- | --- | --- |
| `$RUN_DIR/assembly.fasta` | Phase 3 (polished assembly) | yes |
| `$RUN_DIR/report.md` | `validation/assembly-qc` | strongly recommended |
| `$RUN_DIR/annotation-report.md` | `annotation/genome-annotation` | strongly recommended |
| Organism / genus (user-supplied or detected) | user or `*.gff` header | optional |

### Outputs

| File | Producer | Format | Notes |
| --- | --- | --- | --- |
| `$RUN_DIR/amr_params.json` | this skill | JSON | Machine contract: `tool_set`, `point_mutation_search`, `abricate_dbs`, `organism`, `min_identity`, `min_coverage`. Read by `amr-screening`. |
| `$RUN_DIR/amr_preflight.md` | this skill | Markdown | Audit trail: evidence + per-check verdict + overall verdict + reproducibility footer. Mirrors `validation/assembly-qc`'s `report.md` style. |
| `$RUN_DIR/amr_preflight_evidence.txt` | this skill | text | Raw `seqkit stats` + `grep -c ">"` output, kept for downstream signature matching. |

### Where to write

- Use `$RUN_DIR` (env var) or the current working directory if `$RUN_DIR` is unset.
- The next phase (`amr-screening`) looks for `$RUN_DIR/amr_params.json` + `$RUN_DIR/amr_preflight.md`.

### Verdict gate

`amr-screening` refuses to run unless `$RUN_DIR/amr_preflight.md` overall verdict
is `GO` or `GO-WITH-WARNINGS`. A `NO-GO` verdict stops the pipeline.

## 0.5 Ask-User Stop Points

This sub-skill has **4 stop points** (SP20–SP23). Each fires only when the
evidence is ambiguous. The format is **Evidence + Recommend + Options**. If the
evidence is unambiguous, the agent auto-picks the default and proceeds silently.

### SP20 — Assembly is fragmented (N50 < 50 KB or > 200 contigs)

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `seqkit stats -T assembly.fasta` shows N50 < 50 KB OR contig count > 200 | AMR detection is sensitive to fragmentation | Ask: "Assembly is fragmented (N50 `<X>` KB, `<Y>` contigs). AMR gene calls may be incomplete or split across contigs. Pick: (A) continue anyway (best-effort), (B) re-run assembly with longer reads or higher coverage (recommended), (C) abort" |

**Auto-pick when**: N50 ≥ 50 KB AND contig count ≤ 200. No ask.

### SP21 — Plasmid replicons detected

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `PlasmidFinder` (if installed) or `mlplasmids` reports plasmid replicon(s) in the assembly, OR assembly has > 1 circular contig of size 1–500 KB | AMR genes commonly sit on plasmids; the screening toolset should include plasmid-encoded genes | Ask: "Detected `<X>` plasmid replicon(s) in the assembly. Pick: (A) include plasmid-encoded AMR genes in the screen (recommended), (B) exclude plasmid-encoded genes (chromosomal-only), (C) abort" |

**Auto-pick when**: no plasmid replicons detected AND assembly is single-contig / chromosome-only. Default: include plasmid-encoded genes (most AMR screens want both).

### SP22 — Organism taxonomic group ambiguous

| Trigger | Evidence check | Action |
| --- | --- | --- |
| No organism in `amr_params.json`, no `*.gff` annotation, no user-supplied organism | AMRFinderPlus needs an organism group to narrow point-mutation search | Ask: "I don't know the organism. AMRFinderPlus uses organism-specific point-mutation databases. Pick: (A) I'll provide it now, (B) infer from the assembly (using Kraken2 or Bakta top hit — less accurate), (C) skip point-mutation search (gene-only mode, faster but loses resistance SNPs)" |

**Auto-pick when**: user provides organism in the brief OR `amr_params.json` already has an organism. Default: try Bakta top hit, fall back to "skip point-mutation search" if Bakta annotation is missing.

### SP23 — AMRFinderPlus DB missing or stale

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `amrfinder --version` fails OR DB date is > 12 months old (per NCBI release notes) | NCBI updates AMRFinderPlus DB monthly; major releases every ~12 months | Ask: "AMRFinderPlus DB is missing or > 12 months old. Pick: (A) download / update now (~50 MB, `amrfinder -u`), (B) skip AMRFinderPlus and use ABRicate + RGI only, (C) abort" |

**Auto-pick when**: `amrfinder --version` succeeds and DB date is ≤ 12 months. No ask.

### Operating rule

> **Auto-pick when the evidence is unambiguous; ask when the agent genuinely cannot decide.** When asking, present the evidence first, then the recommendation, then 2–4 concrete options.

## Description

This sub-skill is the **input validation** phase of the AMR screening pipeline.
It computes four pieces of evidence:

1. **Assembly contiguity** — `seqkit stats` for N50, total length, contig count.
2. **Taxonomic classification** — organism name for AMRFinderPlus point-mutation DB selection (auto-inferred from Bakta annotation if missing).
3. **Plasmid evidence** — PlasmidFinder / circular contigs / `mlplasmids` if available.
4. **Tool availability** — `amrfinder --version`, `abricate --version`, `rgi main --version` (if user opted in), plus DB freshness check.

It then writes:

- `amr_params.json` — the machine contract consumed by `amr-screening`.
- `amr_preflight.md` — a human-readable audit trail with a per-check verdict and an overall `GO` / `GO-WITH-WARNINGS` / `NO-GO` verdict.

The design follows `bettamt-preflight` exactly: every recommendation is cited
back to a measured piece of evidence. The agent does not invent parameters —
it computes them.

## Prerequisites

- A polished bacterial genome assembly at `$RUN_DIR/assembly.fasta` (from Phase 3, polishing).
- A completed Phase 3 QC report at `$RUN_DIR/report.md` (overall verdict ≥ `PASS-WITH-WARNINGS`). If `report.md` is `FAIL`, refuse to run.
- The pixi env must have `amrfinder`, `abricate`, and `seqkit` installed (`pixi add amrfinder abricate seqkit`).
- Optional: `rgi`, `staramr`, `plasmidfinder` if the user opts into them.

## Installation

```bash
pixi project channel add conda-forge
pixi project channel add bioconda
pixi add amrfinder abricate seqkit
# Optional, opt-in:
pixi add rgi staramr plasmidfinder
```

AMRFinderPlus DB is downloaded on first use:

```bash
amrfinder -u  # downloads to $HOME/.amrfinderdb/
```

ABRicate ships with 17 DBs that auto-download on first use (`abricate --setupdb`).

## Procedure

### 1. Validate assembly

```bash
test -s "$RUN_DIR/assembly.fasta" || { echo "Missing assembly.fasta"; exit 1; }
seqkit stats -T "$RUN_DIR/assembly.fasta" > "$RUN_DIR/amr_preflight_evidence.txt"
```

Trigger **SP20** if N50 < 50 KB OR contig count > 200 (stop and ask the user).

### 2. Determine organism

Check for organism hints in this order:

1. User-supplied organism (env var `ORGANISM` or `--organism` flag).
2. Bakta annotation: `grep -oP '(?<=locus_tag=).*?(?=;)' "$RUN_DIR/bakta_output/*.gff3" | head -1` (heuristic only).
3. Kraken2 report from Phase 3: `$RUN_DIR/kraken2_report.txt` top hit.

Trigger **SP22** if no organism can be determined.

### 3. Detect plasmid replicons

```bash
# If plasmidfinder is installed:
plasmidfinder.py -i "$RUN_DIR/assembly.fasta" -o "$RUN_DIR/amr_preflight_plasmidfinder" 2>/dev/null
# Heuristic: count circular contigs of 1-500 KB
awk '/^>/{if(len>=1000 && len<=500000) circ++; len=0; next} {len+=length($0)}' \
  "$RUN_DIR/assembly.fasta" > "$RUN_DIR/amr_preflight_plasmid_evidence.txt"
```

Trigger **SP21** if any plasmid replicon is detected.

### 4. Check tool + DB availability

```bash
amrfinder --version 2>/dev/null || echo "amrfinder: missing"
abricate --version 2>/dev/null || echo "abricate: missing"
rgi main --version 2>/dev/null || echo "rgi: missing"
ls -d $HOME/.amrfinderdb/latest 2>/dev/null && echo "AMRFinderPlus DB: present" || echo "AMRFinderPlus DB: missing"
```

Trigger **SP23** if AMRFinderPlus DB is missing or stale.

### 5. Write `amr_params.json`

```json
{
  "assembly": "$RUN_DIR/assembly.fasta",
  "organism": "<resolved-organism>",
  "tool_set": ["amrfinderplus", "abricate"],
  "abricate_dbs": ["card", "resfinder", "argannot"],
  "point_mutation_search": true,
  "include_plasmid_genes": true,
  "min_identity": 80.0,
  "min_coverage": 50.0,
  "threads": "$(nproc)",
  "updated": "<ISO-8601>"
}
```

### 6. Write `amr_preflight.md`

Mirror the `validation/assembly-qc` `report.md` style:

```markdown
# AMR Preflight Report

**Run dir**: `$RUN_DIR`
**Date**: <ISO-8601>
**Verdict**: GO | GO-WITH-WARNINGS | NO-GO

## Per-check verdicts

| Check | Status | Evidence |
| --- | --- | --- |
| Assembly contiguity | PASS | N50 = 320 KB, 1 contig |
| Taxonomic classification | PASS | Organism = Escherichia coli (from Bakta) |
| Plasmid replicons | PASS-WITH-WARNINGS | 1 plasmid replicon detected; user opted to include |
| Tool availability | PASS | amrfinder 4.0, abricate 1.0.1, DB 2026-07-15 |
| Overall | **GO** | all checks PASS or PASS-WITH-WARNINGS |

## Recommendations

- Run amr-screening with the resolved tool_set.
- Cross-validate AMRFinderPlus hits against ABRicate (≥ 2 tools in agreement = gold standard).

## Reproducibility

- pixi env: <env-path>
- amrfinder --version: <output>
- abricate --version: <output>
- seqkit version: <output>
```

## Interpretation Guidelines

| Verdict | Meaning | Action |
| --- | --- | --- |
| `GO` | All checks passed | Proceed to `amr-screening` |
| `GO-WITH-WARNINGS` | One or more checks passed with warnings (e.g. fragmented assembly, plasmid replicons, stale DB) | Proceed, but record warnings in `amr_findings.tsv` metadata |
| `NO-GO` | A hard failure (e.g. missing assembly, missing tool) | Stop; fix the issue and re-run preflight |

## Troubleshooting — Signature library

| Symptom in `amr_preflight_evidence.txt` | Likely cause | Suggested fix |
| --- | --- | --- |
| `seqkit stats` returns 0 rows | assembly.fasta is empty or malformed | Re-check Phase 3 outputs; do not proceed |
| `amrfinder: command not found` | pixi env missing `amrfinder` | `pixi add amrfinder` and re-run |
| `amrfinder -u` fails with `permission denied` | `$HOME/.amrfinderdb` not writable | `mkdir -p ~/.amrfinderdb && chmod 755 ~/.amrfinderdb` |
| `plasmidfinder: command not found` | opt-in tool not installed | `pixi add plasmidfinder` OR accept SP21 default |
| AMRFinderPlus DB download is slow (> 5 min) | NCBI server congestion | Retry; DB is ~50 MB so should complete in 1-2 min |

## Verification

After running preflight, the user should see:

1. `$RUN_DIR/amr_params.json` exists and parses as JSON.
2. `$RUN_DIR/amr_preflight.md` exists and ends with `## Reproducibility`.
3. The overall verdict is `GO` or `GO-WITH-WARNINGS`.

## Output contract

This sub-skill produces exactly three files in `$RUN_DIR`:

- `amr_params.json` (machine contract for `amr-screening`)
- `amr_preflight.md` (human audit trail)
- `amr_preflight_evidence.txt` (raw evidence for downstream signature matching)

The sub-skill produces **no file of its own** beyond these three; all other
paths are inherited from Phase 4.

## What NOT to do

- **Do not skip preflight** and run `amr-screening` directly. The screening sub-skill will refuse to run without `amr_preflight.md` ≥ `GO-WITH-WARNINGS`.
- **Do not invent organism names** — if the user hasn't supplied one and Bakta / Kraken2 don't agree, ask the user (SP22).
- **Do not proceed with a `NO-GO` verdict** even if downstream tools are present. Fix the issue first.
- **Do not run AMRFinderPlus without the DB** — the `-u` download is one command; failing here is a hard `NO-GO`.

## Handoff

After preflight passes, hand off to `amr-screening`:

> **Handoff message (recommended):**
> `amr_preflight.md` verdict is `<GO | GO-WITH-WARNINGS>`. `amr_params.json` recommends `<tool_set>` against `<organism>` with `<min_identity>` / `<min_coverage>` thresholds. Ready to run `amr-screening`?
