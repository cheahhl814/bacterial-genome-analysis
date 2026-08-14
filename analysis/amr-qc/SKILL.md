---
name: amr-qc
description: Build the AMR cross-validation report (amr_report.md) from amr_findings.tsv and the amr_evidence/ directory. Mirrors the validation/assembly-qc report.md style: per-section pass/warn/fail verdicts, an overall verdict (GO / GO-WITH-WARNINGS / NO-GO), and a reproducibility footer. Has 4 explicit ask-user stop points (SP26–SP29) that fire only when evidence is ambiguous. Triggers: "amr qc", "amr report", "build amr_report.md", "interpret amr hits".
version: 5.1.0
updated: "2026-08-14"
triggers:
  - "amr qc"
  - "amr report"
  - "build amr report"
  - "interpret amr hits"
---

# amr-qc — Phase 5a.2 cross-validation report generator

## Audience

Bioinformaticians who need a clinical-decision-ready AMR report from raw
AMRFinderPlus + ABRicate hits. Mirrors the style and verdict pattern of
`validation/assembly-qc/report.md` so downstream tooling (and reviewers) can
treat both reports the same way.

## When to Use This Skill

Use this sub-skill immediately after `amr-screening` has produced
`amr_findings.tsv`. The skill is intentionally simple: it consumes a unified
hit table + raw evidence directory, then synthesizes a Markdown report with
per-section verdicts and an overall pass/warn/fail.

If `amr_findings.tsv` is missing or empty, refuse to run (something upstream
broke).

## 0. Inputs / Outputs contract

### Inputs (the sub-skill refuses to run without these)

| Variable / file | Source | Required? |
| --- | --- | --- |
| `$RUN_DIR/amr_findings.tsv` | `amr-screening` | yes |
| `$RUN_DIR/amr_evidence/amrfinder.tsv` | `amr-screening` | yes |
| `$RUN_DIR/amr_evidence/abricate_*.tsv` | `amr-screening` | yes (one per DB in `amr_params.json`) |
| `$RUN_DIR/amr_params.json` | `amr-preflight` | yes |
| `$RUN_DIR/screening.log` | `amr-screening` | yes |

### Outputs

| File | Producer | Format | Notes |
| --- | --- | --- | --- |
| `$RUN_DIR/amr_report.md` | this skill | Markdown | Main deliverable. Sections: Summary, Per-tool verdicts, Discrepancy table, Cross-validated hits, Recommendations, Reproducibility. |
| `$RUN_DIR/amr_report_evidence.txt` | this skill | text | Raw counts (confirmed/single_tool/etc) for downstream signature matching. |

### Where to write

- Use `$RUN_DIR` (env var) or the current working directory if `$RUN_DIR` is unset.

## 0.5 Ask-User Stop Points

This sub-skill has **4 stop points** (SP26–SP29). Each fires only when the
evidence is ambiguous.

### SP26 — Tools disagree on a clinically important gene

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `amr_findings.tsv` contains a `single_tool` hit where the gene name matches a clinically important class (e.g. `blaCTX-M`, `mcr-1`, `vanA`, `cfr`) | Discrepancies on known high-stakes genes need explicit review | Ask: "Detected a discrepancy on `<gene>` (clinically important). Pick: (A) flag as `single_tool` and proceed with manual review recommended in the report (default), (B) require manual review before publishing the report, (C) abort" |

**Auto-pick when**: all discrepancies are on low-stakes genes. No ask.

### SP27 — Zero hits across all tools

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `amr_findings.tsv` has 0 confirmed AND 0 single_tool hits | Empty result may indicate clean genome OR screening failure | Ask: "Zero hits across all AMR tools. Pick: (A) confirm empty result (genome is clean), (B) re-run screening with broader DBs (e.g. add `ncbi`, `ecoh`), (C) re-run with relaxed thresholds (--minid 70 --mincov 40), (D) abort" |

**Auto-pick when**: at least one confirmed OR one single_tool hit. No ask.

### SP28 — Unusually high AMR burden (≥ 30 hits)

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `wc -l amr_findings.tsv` reports ≥ 30 rows (excluding header) | Most bacterial genomes have < 20 AMR hits; high counts may indicate contamination or a pathogen from a high-resistance environment | Ask: "Detected `<N>` AMR hits (typical: < 20). Pick: (A) include all in the report (full disclosure), (B) filter by strict thresholds (≥ 90% identity, ≥ 80% coverage) before reporting, (C) abort and re-check assembly for contamination" |

**Auto-pick when**: < 30 hits. No ask.

### SP29 — ARIBA data detected in `$RUN_DIR`

| Trigger | Evidence check | Action |
| --- | --- | --- |
| `find $RUN_DIR -name "*ariba*"` finds any ARIBA output files | ARIBA is a legacy tool; if the user has ARIBA data present, they may want it cross-validated too | Ask: "Detected ARIBA output in `$RUN_DIR`. Pick: (A) include ARIBA hits in the cross-validation (3-way comparison), (B) skip ARIBA (use only AMRFinderPlus + ABRicate), (C) abort" |

**Auto-pick when**: no ARIBA output present. No ask.

### Operating rule

> **Auto-pick when the evidence is unambiguous; ask when the agent genuinely cannot decide.**

## Description

This sub-skill reads the unified hit table from `amr-screening`, computes
summary statistics, groups hits by phenotype class, and produces a
clinical-decision-ready Markdown report.

It follows the same structure as `validation/assembly-qc/report.md`:

1. **Summary** — total hits, breakdown by cross-validation status.
2. **Per-tool verdicts** — each tool's raw count and coverage.
3. **Discrepancy table** — genes flagged as `single_tool` for manual review.
4. **Cross-validated hits** — confirmed hits grouped by phenotype class.
5. **Recommendations** — next actions for the user.
6. **Reproducibility** — footer with tool versions, dates, env info.

The report has an overall verdict: `GO` (no concerning findings), `GO-WITH-WARNINGS` (single-tool hits on important genes), or `NO-GO` (massive unexpected findings).

## Prerequisites

- `amr-screening` completed successfully.
- `amr_findings.tsv` exists and is non-empty (or has 0 rows, which triggers SP27).
- The pixi env must have `jq` (for parsing `amr_params.json`).

## Procedure

### 1. Validate inputs

```bash
test -s "$RUN_DIR/amr_findings.tsv" || { echo "Missing amr_findings.tsv"; exit 1; }
test -f "$RUN_DIR/amr_params.json" || { echo "Missing amr_params.json"; exit 1; }
test -d "$RUN_DIR/amr_evidence" || { echo "Missing amr_evidence/"; exit 1; }
```

### 2. Compute summary stats

```bash
TOTAL=$(($(wc -l < "$RUN_DIR/amr_findings.tsv") - 1))
CONFIRMED=$(grep -c "confirmed$" "$RUN_DIR/amr_findings.tsv" || echo 0)
SINGLE=$(grep -c "single_tool$" "$RUN_DIR/amr_findings.tsv" || echo 0)
```

Trigger **SP27** if `TOTAL == 0`.
Trigger **SP28** if `TOTAL >= 30`.
Trigger **SP29** if ARIBA files are present.

### 3. Read phenotype class per hit

For each row in `amr_findings.tsv`, join with raw `amrfinder.tsv` to get the
`Element type` and `Class` fields. Group confirmed hits by class.

### 4. Detect clinically important genes

```bash
CLINICALLY_IMPORTANT="blaCTX-M|blaNDM|blaKPC|blaOXA|mcr-1|mcr-2|vanA|vanB|cfr|tet\(X4\)|optrA|poxtA"
grep -E "$CLINICALLY_IMPORTANT" "$RUN_DIR/amr_findings.tsv" | grep "single_tool$"
```

Trigger **SP26** if any clinically important gene appears with `single_tool` status.

### 5. Build `amr_report.md`

Mirror `validation/assembly-qc/report.md` style:

```markdown
# AMR Cross-Validation Report

**Run dir**: `$RUN_DIR`
**Date**: <ISO-8601>
**Verdict**: GO | GO-WITH-WARNINGS | NO-GO

## Summary

| Status | Count | Notes |
| --- | --- | --- |
| Confirmed (≥ 2 tools) | <N> | High confidence |
| Single-tool | <N> | Manual review recommended |
| Absent | n/a | Not a positive result |
| **Total unique genes** | **<N>** | |

## Per-tool verdicts

| Tool | Hits | Notes |
| --- | --- | --- |
| AMRFinderPlus | <N> | NCBI Pathogen Detection DB |
| ABRicate (CARD) | <N> | ARO ontology |
| ABRicate (Resfinder) | <N> | ResFinder DB |
| ABRicate (ARG-ANNOT) | <N> | ARG-ANNOT DB |

## Discrepancy table (single_tool hits requiring manual review)

| Gene | Detected by | Phenotype | Notes |
| --- | --- | --- | --- |
| <gene> | <tool> | <class> | |

## Cross-validated hits by phenotype

### β-lactam resistance
- `blaTEM-1` (chr) — confirmed by AMRFinderPlus + ABRicate/CARD
- ...

### Aminoglycoside resistance
- ...

### Fluoroquinolone resistance
- ...

### Other / unclassified
- ...

## Recommendations

- For clinical reporting: include only `confirmed` hits.
- For surveillance: include `single_tool` hits as "candidate" and note manual review needed.
- Re-run screening with broader DBs if zero hits were observed.
- For submission to NCBI: convert `confirmed` hits to NCBI's AMR submission format (see `submission/` recipes if available).

## Reproducibility

- pixi env: <env-path>
- amrfinder --version: <output>
- abricate --version: <output>
- seqkit version: <output>
- date: <ISO-8601>
- amr_preflight.md verdict: <verdict>
- amr_params.json: <path>
- amr_findings.tsv row count: <N>
```

### 6. Compute overall verdict

| Condition | Verdict |
| --- | --- |
| Zero hits | `GO` (with note: clean genome) |
| Only confirmed hits, no clinically important single-tool | `GO` |
| Any single-tool hit on a clinically important gene | `GO-WITH-WARNINGS` |
| Discrepancies unresolvable | `NO-GO` |
| User explicitly required manual review (SP26 option B) | `NO-GO` |

### 7. Write `amr_report_evidence.txt`

```bash
{
  echo "## Evidence counts"
  echo "Confirmed: $CONFIRMED"
  echo "Single-tool: $SINGLE"
  echo "Total unique genes: $TOTAL"
  echo ""
  echo "## Phenotype breakdown"
  <phenotype-classified-list>
} > "$RUN_DIR/amr_report_evidence.txt"
```

## Interpretation Guidelines

| Report verdict | Meaning | Next action |
| --- | --- | --- |
| `GO` | Cross-validated hits only; no concerning discrepancies | Safe to use for clinical reporting |
| `GO-WITH-WARNINGS` | Single-tool hits on clinically important genes detected | Manual review recommended before clinical action |
| `NO-GO` | Tools disagree catastrophically OR user required manual review | Do not use for clinical action; resolve discrepancies first |

| Phenotype class | Examples | Clinical significance |
| --- | --- | --- |
| β-lactam | `blaTEM`, `blaCTX-M`, `blaKPC` | Confers resistance to penicillins, cephalosporins, carbapenems |
| Aminoglycoside | `aac(6')-Ib`, `aph(3')-III` | Resistance to gentamicin, amikacin, kanamycin |
| Fluoroquinolone | `gyrA` mutations, `qnrS` | Resistance to ciprofloxacin, levofloxacin |
| Glycopeptide | `vanA`, `vanB` | Vancomycin resistance (VRE) |
| Polymyxin | `mcr-1`, `mcr-2` | Colistin resistance (MCR) |
| Tetracycline | `tet(A)`, `tet(M)` | Tetracycline resistance |
| Macrolide-Lincosamide-Streptogramin B (MLS) | `erm(B)`, `mph(A)` | Erythromycin/clindamycin resistance |

## Troubleshooting — Signature library

| Symptom in `amr_report_evidence.txt` | Likely cause | Suggested fix |
| --- | --- | --- |
| `Total unique genes: 0` | SP27 trigger; genome may be clean OR screening failed | Run SP27 options (re-screen with broader DBs or relaxed thresholds) |
| Discrepancy table has clinically important genes | Tools disagree on known high-stakes gene | SP26 trigger; manual review needed |
| Phenotype class column is empty | AMRFinderPlus did not populate `Class` field | Re-run AMRFinderPlus with `--organism` set explicitly |
| `wc -l` shows huge count | SP28 trigger; possible contamination OR multi-replicon organism | Review preflight evidence for plasmid replicons |

## Verification

After running amr-qc, the user should see:

1. `$RUN_DIR/amr_report.md` exists and ends with `## Reproducibility`.
2. `$RUN_DIR/amr_report.md` has an `Overall verdict` line.
3. The verdict is consistent with the table data (no contradictions).
4. `$RUN_DIR/amr_report_evidence.txt` exists with raw counts.

## Output contract

This sub-skill produces exactly two files in `$RUN_DIR`:

- `amr_report.md` — the user-facing report (main deliverable).
- `amr_report_evidence.txt` — raw counts for downstream signature matching.

The sub-skill produces **no file of its own** beyond these.

## What NOT to do

- **Do not auto-classify `single_tool` hits as confirmed.** They need manual review.
- **Do not hide discrepancies.** The discrepancy table exists for a reason.
- **Do not submit `GO-WITH-WARNINGS` reports as clinical-grade** without manual review.
- **Do not skip the reproducibility footer** — clinical reports require it.
- **Do not propose a verdict that contradicts the table data** (e.g. `GO` when the table lists clinically important discrepancies).

## Handoff

After the report is generated, the AMR pipeline is complete. The user can:

1. Share `amr_report.md` with a clinical reviewer.
2. Use `amr_findings.tsv` for downstream tooling (e.g. resistome analysis).
3. Move to **Phase 5b Virulence Screening** (separate sub-skill) or **Phase 5c Mobilome Profiling** (separate sub-skill).

> **Handoff message (recommended):**
> `amr_report.md` overall verdict is `<GO | GO-WITH-WARNINGS | NO-GO>`. Cross-validated `<N>` genes with `<M>` requiring manual review. See `$RUN_DIR/amr_report.md` for the full breakdown.
