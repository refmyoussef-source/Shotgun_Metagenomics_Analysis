# --- إعدادات الملف للمشروع الكامل ---
# استخدام ملف الـ 120 عينة
SAMPLE_FILE = "samples.txt"

# قراءة القائمة
with open(SAMPLE_FILE) as f:
    SAMPLES = [line.strip() for line in f if line.strip()]

# Rule All: الهدف النهائي هو الملفات المنظفة لجميع العينات
rule all:
    input:
        expand("data/trimmed/{sample}_1.fastq.gz", sample=SAMPLES)

# Rule 1: تحميل الداتا (مع temp لمسحها فوراً)
rule download:
    output:
        r1 = temp("data/raw/{sample}_1.fastq.gz"),
        r2 = temp("data/raw/{sample}_2.fastq.gz")
    params:
        # دالة الروابط الذكية (لـ 9 و 10 أرقام)
        link1 = lambda w: f"ftp://ftp.sra.ebi.ac.uk/vol1/fastq/{w.sample[:6]}/{w.sample}/{w.sample}_1.fastq.gz" if len(w.sample)==9 else f"ftp://ftp.sra.ebi.ac.uk/vol1/fastq/{w.sample[:6]}/00{w.sample[-1]}/{w.sample}/{w.sample}_1.fastq.gz",
        link2 = lambda w: (f"ftp://ftp.sra.ebi.ac.uk/vol1/fastq/{w.sample[:6]}/{w.sample}/{w.sample}_1.fastq.gz" if len(w.sample)==9 else f"ftp://ftp.sra.ebi.ac.uk/vol1/fastq/{w.sample[:6]}/00{w.sample[-1]}/{w.sample}/{w.sample}_1.fastq.gz").replace('_1.fastq.gz', '_2.fastq.gz')
    shell:
        """
        wget -c {params.link1} -O {output.r1}
        wget -c {params.link2} -O {output.r2}
        """

# Rule 2: التنظيف بـ fastp
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
        """
        fastp -i {input.r1} -I {input.r2} \
              -o {output.tr1} -O {output.tr2} \
              -h {output.html} -j {output.json} \
              --detect_adapter_for_pe \
              --thread {threads}
        """
