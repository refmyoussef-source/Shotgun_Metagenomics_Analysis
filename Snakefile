configfile: "config.yaml"

# --- Configuration ---
SAMPLE_FILE = "samples.txt"
KRAKEN_DB = "/home/ubuntu/databases/kraken2" 

# Read samples
with open(SAMPLE_FILE) as f:
    SAMPLES = [line.strip() for line in f if line.strip()]

# --- Rule All ---
rule all:
    input:
        expand("results/kraken/{sample}.report", sample=SAMPLES),
        expand("results/assembly/{sample}/final.contigs.fa", sample=SAMPLES)

# --- Rule 1: Download Raw Data ---
rule download:
    output:
        r1 = temp("data/raw/{sample}_1.fastq.gz"),
        r2 = temp("data/raw/{sample}_2.fastq.gz")
    params:
        link1 = lambda w: f"ftp://ftp.sra.ebi.ac.uk/vol1/fastq/{w.sample[:6]}/{w.sample}/{w.sample}_1.fastq.gz" if len(w.sample)==9 else f"ftp://ftp.sra.ebi.ac.uk/vol1/fastq/{w.sample[:6]}/00{w.sample[-1]}/{w.sample}/{w.sample}_1.fastq.gz",
        link2 = lambda w: (f"ftp://ftp.sra.ebi.ac.uk/vol1/fastq/{w.sample[:6]}/{w.sample}/{w.sample}_1.fastq.gz" if len(w.sample)==9 else f"ftp://ftp.sra.ebi.ac.uk/vol1/fastq/{w.sample[:6]}/00{w.sample[-1]}/{w.sample}/{w.sample}_1.fastq.gz").replace('_1.fastq.gz', '_2.fastq.gz')
    shell:
        "wget -c {params.link1} -O {output.r1} && wget -c {params.link2} -O {output.r2}"

# --- Rule 2: Quality Control (fastp) ---
rule fastp:
    input:
        r1 = "data/raw/{sample}_1.fastq.gz",
        r2 = "data/raw/{sample}_2.fastq.gz"
    output:
        tr1 = "data/trimmed/{sample}_1.fastq.gz",
        tr2 = "data/trimmed/{sample}_2.fastq.gz",
        html = "qc/reports/{sample}.html",
        json = "qc/reports/{sample}.json"
    threads: 4
    shell:
        "fastp -i {input.r1} -I {input.r2} -o {output.tr1} -O {output.tr2} -h {output.html} -j {output.json} --detect_adapter_for_pe --thread {threads}"

# --- Rule 3: Taxonomic Profiling (Kraken2) ---
rule kraken2:
    input:
        tr1 = "data/trimmed/{sample}_1.fastq.gz",
        tr2 = "data/trimmed/{sample}_2.fastq.gz"
    output:
        report = "results/kraken/{sample}.report",
        k2_out = temp("results/kraken/{sample}.output")
    params:
        db = KRAKEN_DB
    threads: 8
    shell:
        "kraken2 --db {params.db} --threads {threads} --paired --output {output.k2_out} --report {output.report} --use-names {input.tr1} {input.tr2}"

# --- Rule 4: Assembly (MEGAHIT) ---
rule megahit:
    input:
        tr1 = "data/trimmed/{sample}_1.fastq.gz",
        tr2 = "data/trimmed/{sample}_2.fastq.gz"
    output:
        contigs = "results/assembly/{sample}/final.contigs.fa"
    params:
        outdir = "results/assembly/{sample}" 
    threads: 8
    shell:
        """
        rm -rf {params.outdir}
        megahit -1 {input.tr1} -2 {input.tr2} -o {params.outdir} -t {threads}
        """