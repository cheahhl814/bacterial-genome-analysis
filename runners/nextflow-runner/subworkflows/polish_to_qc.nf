// Phase 2 -> 3: Polishing -> QC
// Runs QUAST, BUSCO, and CheckM on the polished assembly. Thin wrapper around
// validation/assembly-qc/SKILL.md bash recipe.

include { QUAST } from '../modules/quast'
include { BUSCO } from '../modules/busco'
include { CHECKM } from '../modules/checkm'

workflow polishToQc {
    take:
    assembly_ch // tuple(sample_id, assembly)

    main:
    quast_ch   = Channel.empty()
    busco_ch   = Channel.empty()
    checkm_ch  = Channel.empty()
    if (params.run_quast)  { QUAST(assembly_ch);  quast_ch  = QUAST.out.report }
    if (params.run_busco)  { BUSCO(assembly_ch);  busco_ch  = BUSCO.out.summary }
    if (params.run_checkm) { CHECKM(assembly_ch); checkm_ch = CHECKM.out.report }

    emit:
    quast    = quast_ch
    busco    = busco_ch
    checkm   = checkm_ch
    assembly = assembly_ch
}
