// CheckM completeness/contamination — transcription of
// validation/assembly-qc/SKILL.md bash recipe.
process CHECKM {
    tag "checkm:${sample_id}"
    label 'process_high'

    container 'quay.io/biocontainers/checkm-genome:1.2.5--pyhdfd78af_0'

    input:
    tuple val(sample_id), path(assembly)

    output:
    tuple val(sample_id), path("${sample_id}_checkm"), emit: report

    script:
    """
    mkdir -p checkm_in
    cp ${assembly} checkm_in/${sample_id}.fasta
    checkm lineage_wf \\
        -t ${task.cpus} \\
        -x fasta \\
        checkm_in \\
        ${sample_id}_checkm
    """

    stub:
    """
    mkdir -p ${sample_id}_checkm
    """
}
