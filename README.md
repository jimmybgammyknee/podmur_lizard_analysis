# README

Jimmy Breen (jimmymbreen@gmail.com)  
Alastair Ludington ()

## Lizard analysis for transcript assembly and quantification
The analysis was made up of two strategies, one of which was successful and the other not so much

### Input Data

```
[a1650598@afw 190824_Salva_Lizard]$ ls data/
LSH10.fq.gz  LSH15.fq.gz  LSH21.fq.gz  LSH26.fq.gz  LSH30.fq.gz  LSH35.fq.gz  LSH3.fq.gz   
LSH44.fq.gz  LSH5.fq.gz   LSH11.fq.gz  LSH17.fq.gz  LSH22.fq.gz  LSH27.fq.gz  LSH31.fq.gz  
LSH36.fq.gz  LSH40.fq.gz  LSH45.fq.gz  LSH7.fq.gz   LSH12.fq.gz  LSH18.fq.gz  LSH23.fq.gz
LSH28.fq.gz  LSH32.fq.gz  LSH37.fq.gz  LSH41.fq.gz  LSH46.fq.gz  LSH8.fq.gz   LSH13.fq.gz  
LSH19.fq.gz  LSH24.fq.gz  LSH29.fq.gz  LSH33.fq.gz  LSH38.fq.gz  LSH42.fq.gz  LSH47.fq.gz  LSH9.fq.gz
LSH14.fq.gz  LSH1.fq.gz   LSH25.fq.gz  LSH2.fq.gz   LSH34.fq.gz  LSH39.fq.gz  LSH43.fq.gz  LSH48.fq.gz
```

Data was single-end sequencing ~5-10M reads per sample, which is reasonably low coverage for transcriptome assembly. 
Despite the low coverage, we attempted to assemble the samples by combining all FASTQ files into one large single-fragment sequencing library and running Trinity.

## Transcript Assembly and Annotation

### 1. Reference based alignment using `hisat2`

Initially I looked to use current annotations of Podmur to identify any new transcripts.
You can do this by mapping reads to the reference genome (using `hisat2`) and then using `stringtie` to "assemble" new transcripts.
Below is the process that I run with multiple scripts

```
hisat2-build -p 4 ${BASE}/Podarcis_muralis.PodMur_1.0.dna.toplevel.fa ${BASE}/genome_index/PodMur

for FQ in ${BASE}/data/*.fq.gz; do

        ## Alignment
        hisat2 -p 4 -x ${BASE}/genome_index/PodMur -U $FQ | \
            samtools sort -@ 4 -O BAM -o ${BASE}/2_hisat2/`basename $FQ .fq.gz`.sorted.assembly.bam

        ## Index bam file
        samtools index -@ 4 ${BASE}/2_hisat2/`basename $FQ .fq.gz`.sorted.assembly.bam

done

# Annotation
annotation_file=/apps/bioinfo/share/bcbio/genomes/others/PodMur1.0_CommonWallLizard/rnaseq/Podarcis_muralis.PodMur_1.0.99.gtf

# Create the stringtie output directory
mkdir -p ${base}/4_stringtie

for i in ${base}/2_hisat2/*.sort.bam
 do
        stringtie -G $annotation_file -o ${base}/4_stringtie/$(basename $i .sort.bam).gtf $i
done
```

### 2. _De novo_ assembly using `Trinity`

I would fully detail all the processes, but ive provided 3 scripts that run most of the analysis.
These may need some editing but should work fine.

First script is `runTrinity.sh`, followed by `runTransdecoder.sh` and `runTrinotate.sh`.

These are nicely adapted by Alastair using the documentation setout by the Trinity/Trinotate guys (https://github.com/Trinotate/Trinotate.github.io).
Their documentation is really good so please have a look at those if you have issues.

## Targeted transcript quantification using `salmon`

Given the difficulties with assembling heat shock proteins in the transcript assembly, we then changed track to specifically target heat shock proteins identified by Salva. 
The transcript assembly itself was not sensitive enough to assembly these individually and it is likely that closely related and paralogous genes were _collapsed_ into single models as a results.

Given the quality of the `Podarcis muralis` assembly itself, we added the curated genes that Salva assembled to the current CDS gene fasta and quantified expression of each using the pseudoalignment program `salmon`.
Pseudoalignment should be accurate in distinguishing different versions of each gene, and therefore more successful at identifying specific families of HSPs than an alignment based methods (such as `STAR` or `hisat2`).

```
# Concat the CDS and Salva's HSPs together
cat GCF_004329235.1_PodMur_1.0_rna.fna.gz hsps_annotated.dedup.fa.gz > salmon_PodMur_transcript.fna.gz

# Unzip the files
unpigz salmon_PodMur_transcript.fna.gz

# Run salmon index
salmon index -t salmon_PodMur_transcript.fna -i salmon_idx_31 -p 16

# index that we made for 
idx=./salmon_idx_31

# make output directory
mkdir -p quants

for fn in ../data/*.fq.gz; do
	samp=`basename ${fn}`
	echo "Processing sample ${samp}"
        salmon quant -i ${idx} -l A -r ${fn} \
		--validateMappings -p 8 \
		-o ./quants/${samp}_quant
done 
```


