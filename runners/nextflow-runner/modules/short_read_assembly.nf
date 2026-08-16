// SPAdes short-read assembly — 1-to-1 transcription of
// assembly/short-read-assembly/SKILL.md bash recipe.
process SPADES_ASSEMBLY {
    tag "spades:${sample_id}"
    label 'process_high'

    container 'quay.io/biocontainers/spades:3.15.5--h95f258a_0'

    input:
    tuple val(sample_id), path(reads_R1), path(reads_R2)

    output:
    tuple val(sample_id), path("${sample_id}_assembly.fasta"), emit: assembly
    path "${sample_id}_assembly_log.txt", emit: log

    script:
    """
    spades.py \\
        -1 ${reads_R1} \\
        -2 ${reads_R2} \\
        -o . \\
        -t ${task.cpus} \\
        --careful
    mv scaffolds.fasta ${sample_id}_assembly.fasta
    mv spades.log ${sample_id}_assembly_log.txt
    """

    stub:
    """
    touch ${sample_id}_assembly.fasta ${sample_id}_assembly_log.txt
    """
}
