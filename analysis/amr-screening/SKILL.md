---
name: amr-screening
description: Screen a bacterial genome for antimicrobial resistance (AMR) genes and point mutations using AMRFinderPlus + ABRicate cross-validation. Reads amr_params.json from amr-preflight, runs both tools against the assembly, and writes amr_findings.tsv with cross-validation status per hit. Has 2 explicit ask-user stop points (SP24, SP25) that fire only when evidence is ambiguous. Triggers: "screen for amr", "amr gene screening", "abricate", "amrfinder", "antimicrobial resistance genes".
version: 5.1.0
updated: "2026-08-14"
triggers:
  - "amr screening"
  - "screen for amr genes"
  - "abricate"
  - "amrfinder"
  - "antimicrobial resistance"
---

# amr-screening — Phase 5a.1 cross-validation screening

## Audience

Bioinformaticians running AMR gene screening on a bacterial genome for
clinical, surveillance, or research use. The cross-validation pattern
(AMRFinderPlus + ABRicate) follows the recommendation documented in
`obs-2026-08-13-recommended-phase-5-extension-for-bacterial-genome-analysis-`.

## When to Use This Skill

Use this sub-skill after `amr-preflight` has produced `amr_params.json` and
`amr_preflight.md` with overall verdict ≥ `GO-WITH-WARNINGS`. Always pair with
`amr-qc` immediately afterward — raw TSV hits are not the final deliverable;
the cross-validation report (`amr_report.md`) is.

## 0. Inputs / Outputs contract

### Inputs (the sub-skill refuses to run without these)

| Variable / file | Source | Required? |
| --- | --- | --- |
| `$RUN_DIR/assembly.fasta` | Phase 3 (polished assembly) | yes |
| `$RUN_DIR/amr_params.json` | `amr-preflight` | yes |
| `$RUN_DIR/amr_preflight.md` | `amr-preflight` (verdict ≥ `GO-WITH-WARNINGS`) | yes |

### Outputs

| File | Producer | Format | Notes |
| --- | --- | --- | --- |
| `$RUN_DIR/amr_findings.tsv` | this skill | TSV | Unified cross-validated hit table. Columns: `gene`, `tool`, `database`, `identity`, `coverage`, `contig`, `start`, `end`, `strand`, `phenotype`, `cross_validation_status`. |
| `$RUN_DIR/amr_evidence/amrfinder.tsv` | AMRFinderPlus | TSV | Raw AMRFinderPlus output (kept for transparency). |
| `$RUN_DIR/amr_evidence/abricate_*.tsv` | ABRicate | TSV | Raw ABRicate output per DB (card, resfinder, argannot). |
| `$RUN_DIR/amr_evidence/rgi.tsv` | RGI (opt-in) | TSV | Raw RGI output if user opted in. |
| `$RUN_DIR/screening.log` | this skill | text | Free-form log with tool versions + commands, kept for downstream signature matching. |

### Where to write

- Use `$RUN_DIR` (env var) or the current working directory if `$RUN_DIR` is unset.
- The next phase (`amr-qc`) reads `$RUN_DIR/amr_findings.tsv` and `$RUN_DIR/amr_evidence/` to build the report.

### Verdict gate

`amr-screening` **refuses to run** unless `$RUN_DIR/amr_preflight.md` overall verdict is `GO` or `GO-WITH-WARNINGS`.

## 0.5 Ask-User Stop Points

This sub-skill has **2 stop points** (SP24, SP25). Each fires only when the evidence is ambiguous.

### SP24 — Assembly size unusual (> 10 MB or < 500 KB)

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `seqkit stats` total length > 10 MB OR < 500 KB | Bacterial chromosomes are typically 0.5–10 MB; outside this range is unusual | Ask: "Assembly is `<X>` MB (typical bacteria: 0.5–10 MB). Outside this range may indicate contamination or a non-bacterial sample. Pick: (A) continue anyway (trust preflight's contamination screen), (B) re-run Phase 3 contamination screen, (C) abort" |

**Auto-pick when**: assembly size is 0.5–10 MB. No ask.

### SP25 — ABRicate DB choice ambiguous (user specified multiple)

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `amr_params.json` lists multiple `abricate_dbs` AND user mentioned "comprehensive scan" | ABRicate has 17+ bundled DBs; some users want all | Ask: "amr_params.json lists `<X>` ABRicate DBs (`<list>`). All three cover similar AMR genes but with different sensitivity. Pick: (A) run all `<X>` (recommended for thoroughness, slower), (B) run only `card` (most cited, fastest), (C) run `card + resfinder` (most common surveillance pair), (D) abort" |

**Auto-pick when**: `amr_params.json` lists exactly 3 DBs (CARD + Resfinder + ARG-ANNOT) per default. No ask.

### Operating rule

> **Auto-pick when the evidence is unambiguous; ask when the agent genuinely cannot decide.** When asking, present the evidence first, then the recommendation, then 2–4 concrete options.

## Description

This sub-skill runs AMR gene screening against `$RUN_DIR/assembly.fasta` using
the tool set and DBs configured in `amr_params.json`. The default configuration
is **AMRFinderPlus + ABRicate (CARD + Resfinder + ARG-ANNOT)**, which is the
cross-validation pattern recommended for clinical and surveillance use.

Why two tools? Single-tool AMR screening has known false-positive and
false-negative rates (especially for emerging genes). Cross-validating with two
independent tools and requiring agreement on a hit yields much higher precision.
A gene hit by both tools is reported as `confirmed`; a hit by one tool only is
reported as `single_tool`; a hit by neither (i.e., absent) is `absent`.

This sub-skill is intentionally **stateless**: it produces raw hits, not a
report. The `amr-qc` sub-skill builds the user-facing `amr_report.md` with
pass/warn/fail verdict + reproducibility footer.

## Prerequisites

- A polished bacterial genome assembly at `$RUN_DIR/assembly.fasta`.
- `amr-preflight` completed successfully (overall verdict ≥ `GO-WITH-WARNINGS`).
- The pixi env must have `amrfinder`, `abricate`, and `seqkit`.
- Optional: `rgi` (if user opted in via `amr_params.json`).
- AMRFinderPlus DB downloaded (auto-installed by `amrfinder -u` from preflight).
- ABRicate DBs downloaded (auto-installed by `abricate --setupdb`).

## Installation

Pre-installed via pixi:

```bash
pixi add amrfinder abricate seqkit
# Optional opt-in:
pixi add rgi staramr
```

## Procedure

### 1. Read preflight contract

```bash
test -f "$RUN_DIR/amr_params.json" || { echo "Missing amr_params.json; run amr-preflight first"; exit 1; }
test -f "$RUN_DIR/amr_preflight.md" || { echo "Missing amr_preflight.md"; exit 1; }
VERDICT=$(grep -oP 'Verdict\*\*:\s*\K\S+' "$RUN_DIR/amr_preflight.md")
test "$VERDICT" = "GO" -o "$VERDICT" = "GO-WITH-WARNINGS" || { echo "Preflight verdict is $VERDICT; refusing to run"; exit 1; }

# Parse amr_params.json
TOOL_SET=$(jq -r '.tool_set | join(",")' "$RUN_DIR/amr_params.json")
ORGANISM=$(jq -r '.organism' "$RUN_DIR/amr_params.json")
POINT_MUT=$(jq -r '.point_mutation_search' "$RUN_DIR/amr_params.json")
ABRICATE_DBS=$(jq -r '.abricate_dbs | join(",")' "$RUN_DIR/amr_params.json")
MIN_IDENT=$(jq -r '.min_identity' "$RUN_DIR/amr_params.json")
MIN_COV=$(jq -r '.min_coverage' "$RUN_DIR/amr_params.json")
```

Trigger **SP24** if the assembly is unusually large or small.

### 2. Run AMRFinderPlus

```bash
mkdir -p "$RUN_DIR/amr_evidence"

amrfinder \
  --nucleotide "$RUN_DIR/assembly.fasta" \
  --organism "$ORGANISM" \
  $([ "$POINT_MUT" = "true" ] && echo "--mutation" || echo "--no-point") \
  --threads "$(nproc)" \
  > "$RUN_DIR/amr_evidence/amrfinder.tsv" 2> "$RUN_DIR/screening.log"
```

### 3. Run ABRicate (per DB)

```bash
for db in $(echo "$ABRICATE_DBS" | tr ',' ' '); do
  abricate \
    --db "$db" \
    --minid "$MIN_IDENT" \
    --mincov "$MIN_COV" \
    --threads "$(nproc)" \
    "$RUN_DIR/assembly.fasta" \
    > "$RUN_DIR/amr_evidence/abricate_${db}.tsv" \
    2>> "$RUN_DIR/screening.log"
done
```

Trigger **SP25** only if `abricate_dbs` is empty or contains > 5 DBs (unusual).

### 4. Run RGI (opt-in)

Only if `rgi` is in `tool_set`:

```bash
rgi main \
  --input_sequence "$RUN_DIR/assembly.fasta" \
  --output_file "$RUN_DIR/amr_evidence/rgi" \
  --input_type contig \
  --alignment_tool BLAST \
  --clean \
  --local 2>> "$RUN_DIR/screening.log"
```

### 5. Cross-validate and emit unified `amr_findings.tsv`

```bash
python3 -c "
import csv, json, sys
from pathlib import Path

amr = set()
with open('$RUN_DIR/amr_evidence/amrfinder.tsv') as f:
    for row in csv.DictReader(f, delimiter='\t'):
        if row.get('Gene Symbol'):
            amr.add(row['Gene Symbol'])

abr = {}
for db in '$ABRICATE_DBS'.split(','):
    p = Path(f'$RUN_DIR/amr_evidence/abricate_{db}.tsv')
    if not p.exists(): continue
    with open(p) as f:
        for row in csv.DictReader(f, delimiter='\t'):
            gene = row.get('GENE', '')
            if not gene: continue
            abr.setdefault(gene, []).append({'db': db, 'identity': float(row.get('%COVERAGE', 0))})

with open('$RUN_DIR/amr_findings.tsv', 'w') as out:
    w = csv.writer(out, delimiter='\t')
    w.writerow(['gene','amrfinder_hit','abricate_hit','abricate_dbs','cross_validation_status'])
    for gene in sorted(set(amr) | set(abr)):
        am = gene in amr
        ab = gene in abr
        status = 'confirmed' if (am and ab) else 'single_tool'
        dbs = ','.join(d['db'] for d in abr.get(gene, []))
        w.writerow([gene, am, ab, dbs, status])
"
```

### 6. Write reproducibility footer

Append to `screening.log`:

```bash
{
  echo "## Reproducibility"
  echo "- pixi env: $HOME/.pixi/envs/$(pixi environment list --manifest-path $RUN_DIR/../pixi.toml 2>/dev/null | tail -1)"
  echo "- amrfinder --version: $(amrfinder --version 2>&1)"
  echo "- abricate --version: $(abricate --version 2>&1)"
  echo "- seqkit version: $(seqkit version 2>&1)"
  echo "- date: $(date -Iseconds)"
} >> "$RUN_DIR/screening.log"
```

## Interpretation Guidelines

| Cross-validation status | Meaning | Action |
| --- | --- | --- |
| `confirmed` | Hit in both AMRFinderPlus AND at least one ABRicate DB | High confidence — list in report as confirmed |
| `single_tool` | Hit in only one tool | List in report as single-tool; flag for manual review |
| `absent` | Not hit by either tool | Don't list in report; absence of hit is not a positive result |

| Tool-specific field | Meaning |
| --- | --- |
| `identity` | % nucleotide identity to the reference gene (AMRFinderPlus ≥ 90%, ABRicate ≥ 80%) |
| `coverage` | % of reference gene covered by the assembly hit (≥ 50% is acceptable; ≥ 90% is high-confidence) |
| `phenotype` | Drug class the gene confers resistance to (e.g. β-lactam, aminoglycoside, fluoroquinolone) |

## Troubleshooting — Signature library

| Symptom in `screening.log` | Likely cause | Suggested fix |
| --- | --- | --- |
| `amrfinder: error: --organism is required` | Organism not set in `amr_params.json` | Re-run `amr-preflight` and provide organism (or use `--organism unknown` as fallback) |
| `amrfinder: error: database not found` | AMRFinderPlus DB missing or stale | Run `amrfinder -u`; check `$HOME/.amrfinderdb/latest` |
| `abricate: 0 results` for all DBs | Assembly has no recognizable AMR genes | Check `assembly.fasta` is valid; consider if genome is from a non-bacterial source |
| `rgi: command not found` | RGI not installed (user opted in but did not `pixi add rgi`) | `pixi add rgi` OR remove RGI from `amr_params.json` `tool_set` |
| `rgi main` OOM | RGI is memory-hungry for large assemblies (> 8 MB) | Run RGI on a subsample OR drop RGI for this run |
| Cross-validation produces only `single_tool` hits | Tools disagree on every gene | Check organism-specific DBs are correct; consider running RGI for tie-breaking |

## Verification

After running screening, the user should see:

1. `$RUN_DIR/amr_findings.tsv` exists and has at least the header row.
2. `$RUN_DIR/amr_evidence/amrfinder.tsv` exists (or an empty file if no hits).
3. `$RUN_DIR/amr_evidence/abricate_*.tsv` exists for each DB in `amr_params.json`.
4. `$RUN_DIR/screening.log` ends with `## Reproducibility` footer.

## Output contract

This sub-skill produces exactly the following in `$RUN_DIR`:

- `amr_findings.tsv` — unified cross-validated hit table (the main deliverable).
- `amr_evidence/amrfinder.tsv` — raw AMRFinderPlus output.
- `amr_evidence/abricate_<db>.tsv` — raw ABRicate output per DB.
- `amr_evidence/rgi.tsv` — raw RGI output (only if user opted in).
- `screening.log` — free-form log with reproducibility footer.

The sub-skill produces **no file of its own** beyond these. The next phase,
`amr-qc`, consumes `amr_findings.tsv` and the `amr_evidence/` directory.

## What NOT to do

- **Do not skip `amr-preflight`.** The sub-skill refuses to run without it.
- **Do not run a single tool** and call it done. Cross-validation is the whole point.
- **Do not lower thresholds below the defaults** (`--minid 80 --mincov 50`) without an explicit reason — this dramatically increases false positives.
- **Do not include RGI by default** — it is opt-in for power users only (slow, memory-hungry).
- **Do not interpret `single_tool` hits as confirmed** — flag them for manual review.

## Handoff

After screening completes, hand off to `amr-qc`:

> **Handoff message (recommended):**
> `amr_findings.tsv` has `<N>` rows: `<N_confirmed>` confirmed, `<N_single_tool>` single-tool, `<M>` unique genes. Raw evidence at `$RUN_DIR/amr_evidence/`. Ready to run `amr-qc` to build `amr_report.md`?
