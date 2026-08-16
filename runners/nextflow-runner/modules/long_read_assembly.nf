// Flye long-read assembly — 1-to-1 transcription of
// assembly/long-read-assembly/SKILL.md bash recipe.
process FLYE_ASSEMBLY {
    tag "flye:${sample_id}"
    label 'process_high'

    container 'quay.io/biocontainers/flye:2.9.6--py312h734f728_1'

    input:
    tuple val(sample_id), path(long_reads)

    output:
    tuple val(sample_id), path("${sample_id}_assembly.fasta"), emit: assembly
    path "flye.log", emit: log

    script:
    """
    flye ${params.flye_mode} \\
        --reads ${long_reads} \\
        --out-dir flye_out \\
        --threads ${task.cpus}
    cp flye_out/assembly.fasta ${sample_id}_assembly.fasta
    """

    stub:
    """
    touch ${sample_id}_assembly.fasta flye.log
    """
}
