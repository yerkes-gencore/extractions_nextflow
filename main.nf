#!/usr/bin/env nextflow
nextflow.enable.dsl=2

def helpMessage() {
    log.info """
    Usage:
    The typical command for running the pipeline is as follows:
    ./nextflow run extractions.nf -c nextflow.config

    Edit the nextflow.config file to add run parameters
    """.stripIndent()
}

// Show help message
params.help = ""
if (params.help) {
    helpMessage()
    exit 0
}

// ////////////////////////////////////////////////////
// /* --          VALIDATE INPUTS                 -- */
// ////////////////////////////////////////////////////

def validations() {
    try { 
        file(params.run_dir, checkIfExists: true)
    } catch (e) {
        println "\nRun directory not found. See reference in config.\n\nExiting\n"
        exit 1
    }
    if (!(params.sample_sheets.isEmpty() || (params.sample_sheets instanceof Map && params.sample_sheets.every { k, v -> v instanceof String } ))) {
        println "Parameter 'sample_sheets' is not a map of strings (or empty), please correct and rerun"
        exit 1
    }
}
validations()

// ////////////////////////////////////////////////////
// /* --              PROCESSES                   -- */
// ////////////////////////////////////////////////////

include { check_RTAComplete; bcl2fastq; xml_parse } from './modules/bcl2fastq/main.nf'
include { md5checksums } from './modules/md5sum/main.nf'
include { check_params; runtime_snapshot; mail_extraction_complete } from './modules/workflow_records/main.nf'
include { verify_indices } from './modules/verify_indices/main.nf'

// ////////////////////////////////////////////////////
// /* --               WORKFLOW                   -- */
// ////////////////////////////////////////////////////

workflow extractions {
    main:
        // snapshot run params
        runtime_snapshot(workflow.configFiles.toSet().last(), params.run_dir)
        // Find samplesheets
        if (params.sample_sheets.isEmpty()) {
            Channel.fromPath("${params.run_dir}/*[Dd][Ee][Mm][Uu][Xx]*.csv", type: 'file')
                .set{ sample_sheets }
            println 'No sample sheets explicitly provided, using the following sheets found in the directory'
            sample_sheets | view()
        } else {
            Channel.fromList(params.sample_sheets.keySet())
                .set{ sample_sheets }
        }
        // Verify indices, set barcode mismatch value
        verify_indices(sample_sheets)
        verify_indices.out.stdout.view()
        if (params.auto_calculate_barcodes) {
            barcode_mismatches = verify_indices.out.mismatch_values
        } else {
            barcode_mismatches = params.barcode_mismatches
        }
        // print out params being used
        check_params(verify_indices.out.mismatch_values.collect(), params.run_dir, sample_sheets, barcode_mismatches) | view()
        // Wait for RTA complete
        check_RTAComplete(verify_indices.out.mismatch_values.collect())
        // Run bcl2fastq
        bcl2fastq(check_RTAComplete.out, params.run_dir, sample_sheets, barcode_mismatches)
        // Parse output
        xml_parse(bcl2fastq.out.label, bcl2fastq.out.output_dir)
        if (params.emails?.trim()){
            mail_extraction_complete(xml_parse.out.label, xml_parse.out.demuxstats)
        }
        // compute md5sums in actual folder, don't rely on copied data being similar 
        if (params.compute_md5sums) {
            md5checksums(bcl2fastq.out.label.collect())
        }
    emit:
        bcl2fastq.out.output_dir
}

workflow {
    if (params.delay_start.toFloat() > 0) {
        println "Delaying worfklow by ${params.delay_start} hours"
        Thread.sleep((params.delay_start.toFloat()*1000*3600).intValue())
    }
    println "Workflow start: $workflow.start"
    extractions()
}

// workflow.onComplete {
//     if (workflow.profile != 'dryrun') {
//         if (params.emails?.trim()){
//             def msg = """\
//             Pipeline execution summary
//             ---------------------------
//             Completed at    : ${workflow.complete}
//             Duration        : ${workflow.duration}
//             Success         : ${workflow.success}
//             workDir         : ${workflow.workDir}
//             exit status     : ${workflow.exitStatus}
//             runDir          : ${params.run_dir}
//             NF runName      : ${workflow.runName}
//             """
//             .stripIndent()
//             sendMail(to: "${params.emails}", subject: 'Extraction Complete', body: msg)
//         } 
//     }
// }


// ////////////////////////////////////////////////////
// /* --          IN DEVELOPMENT                  -- */
// ////////////////////////////////////////////////////

// process sync_bcl {
//     //container = "amazon/aws-cli"
//     //containerOptions = "-v $HOME/.aws/credentials"
//     input:
//         path run_dir
//     output:
//         stdout
//     """
//     aws --profile "tki-aws-account-65-rhedcloud/RHEDcloudAdministratorRole" \\
//         s3 sync ${params.run_dir} s3://yerkes-gencore-archive/2022_runs/${params.run_name}/ \\
//         --exclude "*.fastq.gz" --exclude "localcheck*.txt" --exclude "remotecheck*.txt" --exclude "md5-*-Data.txt" --exclude "md5-*-Fastq.txt" \\
//         --no-follow-symlinks --only-show-errors --dryrun 
//     #aws --profile "tki-aws-account-65-rhedcloud/RHEDcloudAdministratorRole" \\
//     #    s3 ls --recursive s3://yerkes-gencore-fastq-archive/2022_runs/${params.run_name}/ | \\
//     #    gawk '{print \$3,\$4}' | sort | sed 's/2022_runs\///1' > remotecheckfastq-${params.run_name}-Fastq.txt
//     """
// }

// process sync_fastq {
//     input:
//         path x
//         val y
//     output:
//         stdout
//     """
//     aws --profile "tki-aws-account-65-rhedcloud/RHEDcloudAdministratorRole" \\
//         s3 sync ${x} s3://yerkes-gencore-fastq-archive/2022_runs/${params.run_name}/ \\
//         --exclude "*" --include "*.fastq.gz" \\
//         --no-follow-symlinks --only-show-errors --dryrun 
//     """
// }

// process init_repo {
//     conda 'conda-forge::gh'
//     output:
//         stdout
//     """
//     gh repo create yerkes-gencore/${params.project_name} --template yerkes-gencore/bulk_template --private
//     """
// }
