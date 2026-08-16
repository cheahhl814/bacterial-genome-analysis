// Unicycler hybrid assembly (short + long reads) — 1-to-1 transcription of
// assembly/hybrid-assembly/SKILL.md bash recipe (recommended hybrid path).
// Note: hybracter (long-first batch tool, CSV input) is intentionally not wrapped —
// use the bash recipe for it.
process UNICYCLER_ASSEMBLY {
    tag "unicycler:${sample_id}"
    label 'process_high'

    container 'quay.io/biocontainers/unicycler:0.5.1--py312hdcc493e_5'

    input:
    tuple val(sample_id), path(reads_R1), path(reads_R2), path(long_reads)

    output:
    tuple val(sample_id), path("${sample_id}_assembly.fasta"), emit: assembly

    script:
    """
    unicycler \\
        -1 ${reads_R1} \\
        -2 ${reads_R2} \\
        -l ${long_reads} \\
        -o unicycler_out \\
        --threads ${task.cpus}
    cp unicycler_out/assembly.fasta ${sample_id}_assembly.fasta
    """

    stub:
    """
    touch ${sample_id}_assembly.fasta
    """
}
