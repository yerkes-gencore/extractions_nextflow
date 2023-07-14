process verify_indices {
    conda 'conda/verify_indices_conda.yml'
    input:
        path samplesheet
    output:
        path 'barcode_mismatch_calculations.txt'
    script:
    """
    python scripts/verify_indices.py -i ${samplesheet} -o barcode_mismatch_calculations.txt
    """
}