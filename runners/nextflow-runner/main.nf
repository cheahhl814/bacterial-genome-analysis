#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { preflightToPolish } from './subworkflows/preflight_to_polish'
include { polishToQc }       from './subworkflows/polish_to_qc'
include { qcToAnnotation }   from './subworkflows/qc_to_annotation'

workflow {

    // ---- input validation (Phase 0 preflight gate) ----
    if (!params.reads && !params.long_reads && !params.sample_sheet) {
        error "Either --reads, --long-reads, or --sample-sheet is required."
    }

    if (params.mode == 'auto') {
        if (params.long_reads && (params.reads || params.sample_sheet)) {
            params.mode = 'hybrid'
        } else if (params.long_reads) {
            params.mode = 'long'
        } else {
            params.mode = 'short'
        }
    }

    if (params.run_bakta && !params.bakta_db) {
        error "Bakta is enabled but --bakta-db was not provided. Point it at a downloaded bakta database directory, or set --run_bakta false."
    }
    if (params.run_kraken && !params.kraken2_db) {
        error "Read contamination screening is enabled but --kraken2-db was not provided."
    }

    // ---- input channels ----
    short_ch = Channel.empty()
    if (params.reads) {
        short_ch = Channel.fromFilePairs(params.reads, checkIfExists: true)
            .map { sample_id, reads -> tuple(sample_id, reads[0], reads[1]) }
    }
    if (params.sample_sheet) {
        sheet_ch = Channel.fromPath(params.sample_sheet)
            .splitCsv(header: true, sep: ',')
            .map { row -> tuple(row.sample_id, file(row.fastq_1), file(row.fastq_2)) }
        short_ch = short_ch.concat(sheet_ch)
    }

    long_ch = Channel.empty()
    if (params.long_reads) {
        long_ch = Channel.fromPath(params.long_reads, checkIfExists: true)
            .map { reads -> tuple(reads.baseName, reads) }
    }

    if (params.mode == 'short') {
        reads_ch = short_ch.map { id, r1, r2 -> tuple(id, r1, r2, null) }
    } else if (params.mode == 'long') {
        reads_ch = long_ch.map { id, lr -> tuple(id, null, null, lr) }
    } else { // hybrid
        reads_ch = short_ch.join(long_ch, by: 0).map { id, r1, r2, lr -> tuple(id, r1, r2, lr) }
    }

    // ---- pipeline (5 phases, mirrors bash sub-skill structure) ----
    preflightToPolish(reads_ch)

    polishToQc(preflightToPolish.out.assembly)

    qcToAnnotation(polishToQc.out.assembly)

    // ---- completion summary ----
    workflow.onComplete {
        log.info "Pipeline run finished. Use -resume to retry any failed steps."
    }
}
