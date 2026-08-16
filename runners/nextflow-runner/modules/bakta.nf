// Bakta genome annotation — transcription of
// annotation/genome-annotation/SKILL.md bash recipe.
process BAKTA_ANNOTATE {
    tag "bakta:${sample_id}"
    label 'process_medium'

    container 'quay.io/biocontainers/bakta:1.12.1--pyhdfd78af_0'

    input:
    tuple val(sample_id), path(assembly)

    output:
    path "${sample_id}_bakta/", emit: results
    path "${sample_id}_bakta/${sample_id}.gff3", emit: gff3

    script:
    """
    bakta \\
        --db ${params.bakta_db} \\
        --output ${sample_id}_bakta \\
        --prefix ${sample_id} \\
        --threads ${task.cpus} \\
        --force \\
        ${assembly}
    """

    stub:
    """
    mkdir -p ${sample_id}_bakta
    touch ${sample_id}_bakta/${sample_id}.gff3
    """
}
