process verify_indices {
    conda "${projectDir}/conda/verify_indices_conda.yml"
    input:
        val samplesheet
    output:
        // path 'barcode_mismatch_calculations.txt'
        stdout  emit: stdout
        env MISMATCH_VALUES, emit: mismatch_values
    script:
    """
    python ${projectDir}/scripts/verify_indices.py -i ${samplesheet} -o barcode_mismatch_calculations.txt
    MISMATCH_VALUES=\$(cat barcode_mismatch_calculations.txt)
    """
}
