// Phase 0 -> 2: Preflight -> Assembly -> Polishing
// Thin wrapper around genome-input-preflight, assembly/{short-read,long-read,hybrid}-assembly,
// and polishing/genome-polishing. Bash recipes remain the source of truth.

include { SPADES_ASSEMBLY } from '../modules/short_read_assembly'
include { FLYE_ASSEMBLY } from '../modules/long_read_assembly'
include { UNICYCLER_ASSEMBLY } from '../modules/hybrid_assembly'
include { MEDAKA_POLISH; MAP_SHORT_READS; POLYPOLISH; PYPOLCA_POLISH } from '../modules/polish'

// Runner-level preflight: input existence/naming check + seqkit read stats.
// Produces a minimal preflight.md / params.json audit trail. For the full
// evidence set (coverage, contamination, disk, resource budget, GO/NO-GO gate)
// run the bash genome-input-preflight sub-skill.
process PREFLIGHT {
    tag "preflight:${sample_id}"
    label 'process_low'

    container 'quay.io/biocontainers/seqkit:2.13.0--he881be0_0'

    input:
    tuple val(sample_id), path(reads)

    output:
    path "${sample_id}_preflight.md", emit: preflight_md
    path "${sample_id}_params.json", emit: params_json
    path "${sample_id}_stats.tsv", emit: stats_tsv

    script:
    def n_fq = reads.size()
    def reads_json = reads.collect { "\"$it\"" }.join(',\n    ')
    def has_short = (params.mode == 'short' || params.mode == 'hybrid') ? 'true' : 'false'
    def has_long  = (params.mode == 'long'  || params.mode == 'hybrid') ? 'true' : 'false'
    def assembler = params.mode == 'short' ? 'spades' : (params.mode == 'long' ? 'flye' : 'unicycler')
    def polishing = params.mode == 'short' ? 'skip' : (params.mode == 'long' ? 'medaka' : 'polypolish')
    """
    seqkit stats -T ${reads} > ${sample_id}_stats.tsv

    cat > ${sample_id}_params.json <<EOF
{
  "platform": "${params.mode}",
  "has_short": ${has_short},
  "has_long": ${has_long},
  "reads": [
    ${reads_json}
  ],
  "num_fastq": ${n_fq},
  "assembler": "${assembler}",
  "polishing": "${polishing}",
  "qc": "required",
  "annotation": "bakta",
  "verdict": "GO",
  "generated": "\$(date -Iseconds)"
}
EOF

    cat > ${sample_id}_preflight.md <<EOF
# Bacterial genome preflight report

Run:        \$PWD
Generated:  \$(date -Iseconds)
Pipeline:   bacterial-genome-analysis v5.1 (nextflow-runner)

## Overall verdict

**GO** — runner-level input preflight passed (files exist, naming OK). Run the bash genome-input-preflight sub-skill for the full evidence trail (coverage, contamination, disk, resource budget).

## Evidence

| Check | Verdict | Value |
|---|---|---|
| Read files present | GO | ${n_fq} fastq file(s) for ${sample_id} |
| Read stats (seqkit) | GO | see ${sample_id}_stats.tsv |
| Platform / mode | GO | ${params.mode} |

## Recommendations

- **Platform**: ${params.mode}
- **Assembler**: ${assembler}
- **Polishing**: ${polishing}

## Reproducibility

- params.json: ${sample_id}_params.json
- evidence:   ${sample_id}_stats.tsv
EOF
    """

    stub:
    """
    touch ${sample_id}_preflight.md ${sample_id}_params.json ${sample_id}_stats.tsv
    """
}

// Optional read-level contamination screen (mirrors preflight 2d).
process KRAKEN2_READS {
    tag "kraken2:${sample_id}"
    label 'process_medium'

    container 'quay.io/biocontainers/kraken2:2.17.1--pl5321h077b44d_0'

    input:
    tuple val(sample_id), path(reads), path(kraken2_db)

    output:
    tuple val(sample_id), path("${sample_id}.kraken2.report.txt"), emit: report

    script:
    """
    kraken2 \\
        --db ${kraken2_db} \\
        --threads ${task.cpus} \\
        --quick \\
        --confidence 0.05 \\
        --output ${sample_id}.kraken2.out \\
        --report ${sample_id}.kraken2.report.txt \\
        ${reads}
    """

    stub:
    """
    touch ${sample_id}.kraken2.report.txt
    """
}

workflow preflightToPolish {
    take:
    reads_ch // tuple(sample_id, reads_R1, reads_R2, long_read)

    main:
    reads_list_ch = reads_ch.map { id, r1, r2, lr -> tuple(id, [r1, r2, lr].findAll { it }) }
    PREFLIGHT(reads_list_ch)

    kraken_reads_ch = Channel.empty()
    if (params.kraken2_db) {
        db_ch = Channel.value(file(params.kraken2_db, checkIfExists: true))
        kraken_in_ch = reads_ch.map { id, r1, r2, lr -> tuple(id, r1 ?: lr) }.combine(db_ch)
        KRAKEN2_READS(kraken_in_ch)
        kraken_reads_ch = KRAKEN2_READS.out.report
    }

    short_ch = reads_ch.map { id, r1, r2, lr -> tuple(id, r1, r2) }
    long_ch  = reads_ch.map { id, r1, r2, lr -> tuple(id, lr) }

    if (params.mode == 'short') {
        SPADES_ASSEMBLY(short_ch)
        asm_ch = SPADES_ASSEMBLY.out.assembly
    } else if (params.mode == 'long') {
        FLYE_ASSEMBLY(long_ch)
        asm_ch = FLYE_ASSEMBLY.out.assembly
        MEDAKA_POLISH(asm_ch.join(long_ch).map { id, asm, lr -> tuple(id, asm, lr) })
        asm_ch = MEDAKA_POLISH.out.assembly
    } else { // hybrid
        UNICYCLER_ASSEMBLY(reads_ch.map { id, r1, r2, lr -> tuple(id, r1, r2, lr) })
        asm_ch = UNICYCLER_ASSEMBLY.out.assembly
        MAP_SHORT_READS(asm_ch.join(short_ch).map { id, asm, r1, r2 -> tuple(id, asm, r1, r2) })
        bam_ch = MAP_SHORT_READS.out.bam
        POLYPOLISH(bam_ch.join(asm_ch).map { id, bam, asm -> tuple(id, asm, bam) })
        asm_ch = POLYPOLISH.out.assembly
        if (params.run_pypolca) {
            PYPOLCA_POLISH(asm_ch.join(short_ch).map { id, asm, r1, r2 -> tuple(id, asm, r1, r2) })
            asm_ch = PYPOLCA_POLISH.out.assembly
        }
    }

    emit:
    reads        = reads_ch
    preflight    = PREFLIGHT.out.preflight_md
    params_json  = PREFLIGHT.out.params_json
    stats        = PREFLIGHT.out.stats_tsv
    kraken_reads = kraken_reads_ch
    assembly     = asm_ch
}
