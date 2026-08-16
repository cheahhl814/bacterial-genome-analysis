// BUSCO genome completeness — transcription of
// validation/assembly-qc/SKILL.md bash recipe.
process BUSCO {
    tag "busco:${sample_id}"
    label 'process_high'

    container 'quay.io/biocontainers/busco:6.1.0--pyhdfd78af_1'

    input:
    tuple val(sample_id), path(assembly)

    output:
    path "${sample_id}_busco/run_busco/short_summary*.txt", emit: summary
    path "${sample_id}_busco/", emit: report

    script:
    """
    busco \\
        -i ${assembly} \\
        -o run_busco \\
        --out_path ${sample_id}_busco \\
        --mode genome \\
        --lineage_dataset ${params.busco_lineage} \\
        --cpu ${task.cpus}
    """

    stub:
    """
    mkdir -p ${sample_id}_busco/run_busco
    touch ${sample_id}_busco/run_busco/short_summary.txt
    """
}
