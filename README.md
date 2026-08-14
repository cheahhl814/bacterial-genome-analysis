# Bacterial Genome Analysis Skills

> **v5.0.1.** Added a new `preflight` sub-skill (Phase 0) that gates the assembly phase on a `GO` / `GO-WITH-WARNINGS` / `NO-GO` verdict. v5 structure (orchestrator + 4 specialists) is unchanged. Pattern matches `bettamt-preflight` from [BettaMt-agents](https://github.com/cheahhl814/BettaMt-agents).

This meta-skill orchestrates the end-to-end reconstruction of bacterial genomes, transforming cleaned sequencing reads into a validated, polished, and annotated genomic sequence. It implements the **"Finished Genome"** paradigm, ensuring that assembly errors are corrected before biological features are labeled.

> **Dual-Audience Design**: This meta-skill is designed to serve **both AI coding agents and human bioinformaticians**. The structured triggers, evidence chains, and Go/No-Go gates guide autonomous execution, while the embedded "When to Use", "Why This Tool", "Conceptual Background", and "Troubleshooting" sections provide human readers with the intuition to make informed decisions.

## Pipeline Overview

The analysis follows a strict **5-phase evidence chain** (building upon upstream read QC, covered by the separate [`read-qc-trimming`](https://github.com/cheahhl814/read-qc-trimming) skill). Moving to a subsequent phase requires passing a "Go/No-Go" quality gate AND emitting the artifact the next phase expects.

| # | Phase | Goal | Sub-Skill | Artifact produced |
|:---|:---|:---|:---|:---|
| **0** | **Preflight** (The Audit) | Validate inputs, compute evidence, write `params.json` + `preflight.md`. | `/preflight` | `$RUN_DIR/preflight.md` + `$RUN_DIR/params.json` |
| **1** | **Assembly** (The Draft) | Generate initial contigs from cleaned reads. | `/assembly` | `$RUN_DIR/draft.fasta` |
| **2** | **Polishing** (The Correction) | Correct base-level errors (INDELs, SNPs). | `/polishing` | `$RUN_DIR/assembly.fasta` |
| **3** | **Validation** (The Quality Gate) | Quantify contiguity, completeness, contamination. | `/validation` | `$RUN_DIR/report.md` |
| **4** | **Annotation** (The Labeling) | Identify and label biological features. | `/annotation` | `$RUN_DIR/bakta_output/<prefix>.{gff3,gbff,faa,fna}` |

### Phase Selection Logic

- **Phase 1a (Short-Read)**: Use Illumina data only $\rightarrow$ produces fragmented drafts.
- **Phase 1b (Long-Read)**: Use ONT/PacBio data only $\rightarrow$ produces near-complete genomes.
- **Phase 1c (Hybrid)**: Use both $\rightarrow$ the **gold standard** for closed genomes.

## v5 design — what changed

### v5.0.1 (current)

- New **Phase 0 Preflight** sub-skill at `preflight/genome-input-preflight/` — runs `seqkit stats`, `minimap2` downsampled coverage, `kraken2` read-level screen, disk / resource checks, and tool availability. Writes `params.json` (machine contract) and `preflight.md` (audit trail) with overall verdict `GO` / `GO-WITH-WARNINGS` / `NO-GO`.
- The **three assembly sub-skills refuse to run** without `preflight.md` ≥ `GO-WITH-WARNINGS`.
- Orchestrator stage detection ladder now triggers `preflight` when cleaned reads exist but `preflight.md` is missing.
- Handoff contract table now includes `preflight → assembly` (params.json + preflight.md).

### v5.0.0 (initial restructure)

| Change | v4 (old) | v5.0.0 (new) |
| --- | --- | --- |
| Orchestrator | None — master SKILL.md was a wall of phases | §0 orchestrator: detects stage from filesystem evidence and routes to the right sub-skill |
| Handoff contract | Prose ("prerequisites: cleaned reads...") | Tabular §B in master + §0 Inputs/Outputs contract in every sub-skill |
| QC report | Just a recipe for running QUAST/CheckM/BUSCO/Kraken2 | `validation/assembly-qc` now **writes `$RUN_DIR/report.md`** with pass/warn/fail verdicts |
| Troubleshooting | Free-form paragraphs | **Signature library** table per sub-skill: stderr pattern $\rightarrow$ likely cause $\rightarrow$ suggested fix |
| Anti-patterns | Implicit | Explicit "What NOT to do" section in every sub-skill |
| Disk check | Missing | §F.2 in master + every sub-skill respects `$RUN_DIR` env var |
| Skip polish shortcut | Implicit | Master explicitly distinguishes "always polish (long-read)" vs "optional polish (short-read)" |

### What did NOT change (since v4)

- **The 4-phase pipeline architecture** itself (Assembly $\rightarrow$ Polishing $\rightarrow$ Validation $\rightarrow$ Annotation) — still grounded in `nf-core/bacass`.
- **The Go/No-Go gate logic** — 90/10 warning + 95/5 strict MIMAG.
- **The bash recipes** in each sub-skill — only the surrounding contract and signature library were added.
- **The pixi.toml** — tools unchanged.

## When to Use This Skill

✅ **Use this skill** when you need to:
- Reconstruct a bacterial genome **de novo** (without a reference).
- Achieve a **complete, closed genome** (single contig per replicon).
- Identify AMR genes, virulence factors, or metabolic pathways.
- Submit a genome to NCBI (requires GenBank annotation).

❌ **Do NOT use this skill** for:
- Reference-based variant calling (use a variant calling pipeline).
- Eukaryotic, viral, or metagenomic data (different paradigms apply).
- Raw read statistics (use the `read-qc-trimming` skill).

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

The agent will respond to triggers such as *"assemble bacterial genome"*, *"complete bacterial assembly"*, *"annotate bacterial genome"*, or *"is my bacterial genome ready"* and execute the 4-phase workflow.

### For Human Users

1. **Read the Master `SKILL.md`** for the pipeline architecture, orchestrator routing, and glossary.
2. **Navigate to the relevant sub-skill** based on your data type (short/long/hybrid).
3. **Follow the "When to Use", "Why This Tool", and "Troubleshooting" sections** for decision support.
4. **Use the Go/No-Go gates** as checkpoints to ensure quality at each phase.
5. **Read `$RUN_DIR/report.md`** at the end of QC — it's the single document with all verdicts.

## Agent Skills Standard compliance

This skill follows the [Agent Skills standard](https://agentskills.io/specification):

- ✅ **YAML frontmatter** on every `SKILL.md`: `name`, `description`, `version`, `updated`, `triggers`.
- ✅ **Trigger phrases** in `description` — agents auto-load the skill on matching user prompts.
- ✅ **Inputs/Outputs contract** at the top of every sub-skill (`§0`).
- ✅ **Output contract** at the bottom of every sub-skill (what files it produces).
- ✅ **What NOT to do** section in every sub-skill (anti-patterns).
- ✅ **Signature library** (troubleshooting table) in every sub-skill that runs external tools.

**Auto-discovered by** (project-local, scanned from `cwd` upward to the repo root):

- ✅ **pi** — this is the tool writing this README. Scans `SKILL.md` after the project is marked trusted.
- ✅ **OpenCode** — scans the skill directory and walks up.
- ✅ **Codex** — scans the skill directory and walks up.
- ❌ **Claude Code** — does not scan the conventional locations by default. If you also need Claude Code to see this skill, see [anthropics/claude-code#33733](https://github.com/anthropics/claude-code/issues/33733).

To install globally for one user, copy or symlink the skill to your user-scope path:

| Tool | User-scope path |
|---|---|
| pi | `~/.pi/agent/skills/` |
| OpenCode | `~/.config/opencode/skills/` or `~/.agents/skills/` |
| Codex | `~/.agents/skills/` |

## File Structure

```
bacterial-genome-analysis/
├── SKILL.md                              # Master orchestrator (§0 stage detection, §B handoff contract, glossary)
├── README.md                              # This file (Public overview)
├── pixi.toml                              # Conda/pixi environment declaration (29 tools)
├── preflight/
│   └── genome-input-preflight/SKILL.md  # Phase 0: validate inputs, compute evidence, write params.json + preflight.md
├── assembly/
│   ├── short-read-assembly/SKILL.md     # De Bruijn Graph paradigm; SPAdes/SKESA/MEGAHIT
│   ├── long-read-assembly/SKILL.md      # OLC paradigm; Flye/Autocycler/Dragonflye
│   └── hybrid-assembly/SKILL.md        # Hybrid paradigms; Unicycler/Dragonflye/Hybracter
├── polishing/
│   └── genome-polishing/SKILL.md        # Two-stage polishing (Long-read → Short-read)
├── validation/
│   └── assembly-qc/SKILL.md             # Three Pillars of QC + report.md verdict generator
└── annotation/
    └── genome-annotation/SKILL.md       # Bakta-centric annotation with UniRef database
```

## Why this design?

This is the agentic-skill pattern documented by `BettaMt-agents` (https://github.com/cheahhl814/BettaMt-agents). Key principles borrowed from there:

1. **The agent reasons; the skill executes.** Sub-skills don't try to be smart — they have a single responsibility and produce specific files.
2. **The filesystem is the boundary.** Inputs and outputs are explicit file paths, not agent memory.
3. **The orchestrator is a router.** The master `SKILL.md` does not duplicate logic; it detects the stage and routes.
4. **Confidence-labeled hypotheses.** Every signature-library row is "stderr pattern $\rightarrow$ likely cause $\rightarrow$ suggested fix" — the agent reads the actual error first, then matches.

## License

This skill's text and code are released under the MIT License.
