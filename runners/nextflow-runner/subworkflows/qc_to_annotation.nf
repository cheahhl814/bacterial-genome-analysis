// Phase 3 -> 4: QC -> Annotation
// Bakta functional annotation of the polished/QC-passed assembly. Thin wrapper
// around annotation/genome-annotation/SKILL.md bash recipe.

include { BAKTA_ANNOTATE } from '../modules/bakta'

workflow qcToAnnotation {
    take:
    assembly_ch // tuple(sample_id, assembly)

    main:
    annotation_ch = Channel.empty()
    gff3_ch = Channel.empty()
    if (params.run_bakta) {
        BAKTA_ANNOTATE(assembly_ch)
        annotation_ch = BAKTA_ANNOTATE.out.results
        gff3_ch = BAKTA_ANNOTATE.out.gff3
    }

    emit:
    annotation = annotation_ch
    gff3       = gff3_ch
    assembly   = assembly_ch
}
