// Polishing — Medaka (long reads), Polypolish + Pypolca (short reads).
// 1-to-1 transcriptions of polishing/genome-polishing/SKILL.md bash recipes.

// Medaka consensus polishing (ONT long reads).
process MEDAKA_POLISH {
    tag "medaka:${sample_id}"
    label 'process_medium'

    container 'quay.io/biocontainers/medaka:2.2.2--py312h3050eb1_0'

    input:
    tuple val(sample_id), path(assembly), path(long_reads)

    output:
    tuple val(sample_id), path("${sample_id}_polished.fasta"), emit: assembly

    script:
    """
    medaka_consensus \\
        -i ${long_reads} \\
        -d ${assembly} \\
        -o medaka_out \\
        -t ${task.cpus} \\
        -m ${params.medaka_model}
    cp medaka_out/consensus.fasta ${sample_id}_polished.fasta
    """

    stub:
    """
    touch ${sample_id}_polished.fasta
    """
}

// Map short reads to an assembly with bwa + samtools (needed by Polypolish/Pypolca).
// Uses the pypolca image, which bundles bwa and samtools.
process MAP_SHORT_READS {
    tag "map:${sample_id}"
    label 'process_medium'

    container 'quay.io/biocontainers/pypolca:0.4.0--pyhdfd78af_0'

    input:
    tuple val(sample_id), path(assembly), path(reads_R1), path(reads_R2)

    output:
    tuple val(sample_id), path("${sample_id}.sorted.bam"), emit: bam

    script:
    """
    bwa index ${assembly}
    bwa mem -t ${task.cpus} ${assembly} ${reads_R1} ${reads_R2} | \\
        samtools sort -@ ${task.cpus} -O BAM -o ${sample_id}.sorted.bam
    samtools index ${sample_id}.sorted.bam
    """

    stub:
    """
    touch ${sample_id}.sorted.bam
    """
}

// Polypolish short-read polishing of a hybrid assembly.
process POLYPOLISH {
    tag "polypolish:${sample_id}"
    label 'process_medium'

    container 'quay.io/biocontainers/polypolish:0.7.1--hec9b1f2_0'

    input:
    tuple val(sample_id), path(assembly), path(reads_bam)

    output:
    tuple val(sample_id), path("${sample_id}_polypolish.fasta"), emit: assembly

    script:
    """
    polypolish polish ${assembly} ${reads_bam} > ${sample_id}_polypolish.fasta
    """

    stub:
    """
    touch ${sample_id}_polypolish.fasta
    """
}

// Pypolca short-read polishing — optional extra round after Polypolish
// (enable with --run_pypolca true).
process PYPOLCA_POLISH {
    tag "pypolca:${sample_id}"
    label 'process_medium'

    container 'quay.io/biocontainers/pypolca:0.4.0--pyhdfd78af_0'

    input:
    tuple val(sample_id), path(assembly), path(reads_R1), path(reads_R2)

    output:
    tuple val(sample_id), path("${sample_id}_pypolca.fasta"), emit: assembly

    script:
    """
    pypolca run \\
        -a ${assembly} \\
        -1 ${reads_R1} \\
        -2 ${reads_R2} \\
        -t ${task.cpus} \\
        -o pypolca_out \\
        -p ${sample_id}
    mv pypolca_out/${sample_id}_corrected.fasta ${sample_id}_pypolca.fasta
    """

    stub:
    """
    touch ${sample_id}_pypolca.fasta
    """
}
