// QUAST de-novo assembly QC — transcription of
// validation/assembly-qc/SKILL.md bash recipe.
process QUAST {
    tag "quast:${sample_id}"
    label 'process_low'

    container 'quay.io/biocontainers/quast:5.3.0--py312pl5321hdcc493e_1'

    input:
    tuple val(sample_id), path(assembly)

    output:
    tuple val(sample_id), path("${sample_id}_quast"), emit: report

    script:
    def est_ref_size = params.genome_size ? "--est-ref-size ${params.genome_size}" : ""
    """
    quast.py ${assembly} \\
        -o quast_out \\
        --threads ${task.cpus} \\
        --no-icarus \\
        ${est_ref_size}
    mv quast_out ${sample_id}_quast
    """

    stub:
    """
    mkdir -p ${sample_id}_quast
    """
}
