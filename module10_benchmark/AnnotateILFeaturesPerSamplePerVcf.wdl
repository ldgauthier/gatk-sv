##########################################################################################

## Github commit: talkowski-lab/gatk-sv-v1:<ENTER HASH HERE IN FIRECLOUD>

##########################################################################################

## Copyright Broad Institute, 2020
## 
## This WDL pipeline implements Duphold 
##
##
## LICENSING : 
## This script is released under the WDL source code license (BSD-3) (see LICENSE in 
## https://github.com/broadinstitute/wdl). Note however that the programs it calls may 
## be subject to different licenses. Users are responsible for checking that they are
## authorized to run all programs before running this script. Please see the docker 
## page at https://hub.docker.com/r/broadinstitute/genomes-in-the-cloud/ for detailed
## licensing information pertaining to the included programs.

version 1.0

import "Structs.wdl"
import "TasksBenchmark.wdl" as mini_tasks
import "AnnotateILFeaturesPerSamplePerVcfUnit.wdl" as anno_il

workflow AnnotateILFeaturesPerSamplePerVcf{
    input{
        File cleanVcf

        String prefix
        String sample

        File raw_manta
        File raw_wham
        File raw_melt
        File? array_query

        File ref_fasta
        File ref_fai
        File ref_dict
        File contig_list

        Boolean requester_pays_crams = false
        Boolean run_genomic_context_anno = false
        Boolean run_extract_algo_evi = false
        Boolean run_duphold = false
        Boolean run_extract_gt_gq = true
        Boolean run_versus_raw_vcf = true
        Boolean run_rdpesr_anno = true

        String rdpesr_benchmark_docker
        String duphold_docker
        String sv_base_mini_docker
        String sv_pipeline_docker

        RuntimeAttr? runtime_attr_duphold
        RuntimeAttr? runtime_attr_rdpesr
        RuntimeAttr? runtime_attr_bcf2vcf
        RuntimeAttr? runtime_attr_LocalizeCram
        RuntimeAttr? runtime_attr_vcf2bed
        RuntimeAttr? runtime_attr_SplitVcf
        RuntimeAttr? runtime_attr_ConcatBeds
        RuntimeAttr? runtime_attr_ConcatVcfs
        RuntimeAttr? runtime_inte_anno
        RuntimeAttr? runtime_attr_split_vcf
    }

    call mini_tasks.split_per_sample_vcf as split_per_sample_vcf{
        input:
            vcf = cleanVcf,
            sample = sample,
            sv_pipeline_docker = sv_pipeline_docker,
            runtime_attr_override = runtime_attr_split_vcf
    }

    call anno_il.AnnoILFeaturesPerSample as anno_il_features{
        input:
            sample = sample,
            vcf_file = split_per_sample_vcf.vcf_file,

            ref_fasta = ref_fasta,
            ref_fai = ref_fai,
            ref_dict = ref_dict,
            contig_list = contig_list,

            raw_vcfs = [raw_manta,raw_wham,raw_melt],
            raw_algorithms = ["manta","wham","melt"],

            array_query = array_query,

            rdpesr_benchmark_docker = rdpesr_benchmark_docker,
            duphold_docker = duphold_docker,
            sv_base_mini_docker = sv_base_mini_docker,
            sv_pipeline_docker = sv_pipeline_docker,

            requester_pays_crams = requester_pays_crams,
            run_genomic_context_anno = run_genomic_context_anno,
            run_extract_algo_evi = run_extract_algo_evi,
            run_duphold = run_duphold,
            run_extract_gt_gq = run_extract_gt_gq,
            run_versus_raw_vcf = run_versus_raw_vcf,
            run_rdpesr_anno = run_rdpesr_anno,

            runtime_attr_duphold = runtime_attr_duphold,
            runtime_attr_rdpesr = runtime_attr_rdpesr,
            runtime_attr_bcf2vcf = runtime_attr_bcf2vcf,
            runtime_attr_LocalizeCram = runtime_attr_LocalizeCram,
            runtime_attr_vcf2bed = runtime_attr_vcf2bed,
            runtime_attr_SplitVcf = runtime_attr_SplitVcf,
            runtime_attr_ConcatBeds = runtime_attr_ConcatBeds,
            runtime_attr_ConcatVcfs = runtime_attr_ConcatVcfs
    }

    call IntegrateAnno{
        input:
            prefix = " ~{sample}.~{prefix}",
            sample = sample,
            bed           = anno_il_features.bed,
            gc_anno       = anno_il_features.GCAnno,
            duphold_il    = anno_il_features.duphold_vcf_il,
            duphold_il_le = anno_il_features.duphold_vcf_il_le,
            duphold_il_ri = anno_il_features.duphold_vcf_il_ri,
            pesr_anno     = anno_il_features.PesrAnno,
            rd_anno       = anno_il_features.RdAnno,
            rd_le_anno    = anno_il_features.RdAnno_le,
            rd_ri_anno    = anno_il_features.RdAnno_ri,
            gt_anno       = anno_il_features.GTGQ,
            info_anno     = anno_il_features.vcf_info,
            raw_manta     = anno_il_features.vs_raw[0],
            raw_wham      = anno_il_features.vs_raw[1],
            raw_melt      = anno_il_features.vs_raw[2],
            vs_array      = anno_il_features.vs_array,
            rdpesr_benchmark_docker = rdpesr_benchmark_docker,
            runtime_attr_override = runtime_inte_anno
    }


    output{
        File annotated_file = IntegrateAnno.anno_file
    }
}


task IntegrateAnno{
    input{
        File bed
        File? gc_anno
        File? duphold_il
        File? duphold_il_le
        File? duphold_il_ri
        File? rd_anno
        File? rd_le_anno
        File? rd_ri_anno
        File? pesr_anno
        File? info_anno
        File? gt_anno
        File raw_manta
        File raw_wham
        File raw_melt
        File? vs_pacbio
        File? vs_bionano
        File? vs_array
        File? denovo
        String prefix
        String sample
        String rdpesr_benchmark_docker
        RuntimeAttr? runtime_attr_override
        }

    RuntimeAttr default_attr = object {
        cpu_cores: 1, 
        mem_gb: 3.75, 
        disk_gb: 10,
        boot_disk_gb: 10,
        preemptible_tries: 1,
        max_retries: 1
    }
    
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])

    output{
        File anno_file = "~{prefix}.anno.bed.gz"
    }
    
    command <<<
        
        ~{if defined(rd_anno) then "zcat ~{rd_anno} | grep ~{sample}  > ~{sample}.rd_anno"  else ""}
        ~{if defined(pesr_anno) then "zcat ~{pesr_anno} | grep ~{sample} > ~{sample}.pesr_anno"  else ""}

        Rscript /src/integrate_annotations.R --bed ~{bed} \
            --output ~{prefix}.anno.bed \
            --raw_manta ~{raw_manta} \
            --raw_wham ~{raw_wham} \
            --raw_melt ~{raw_melt} \
            ~{"--vs_pacbio " + vs_pacbio} \
            ~{"--vs_bionano " + vs_bionano} \
            ~{"--vs_array " + vs_array} \
            ~{"--gc_anno " + gc_anno} \
            ~{"--duphold_il " + duphold_il} \
            ~{"--duphold_il_le " + duphold_il_le} \
            ~{"--duphold_il_ri " + duphold_il_ri} \
            ~{"--rd_le " + rd_le_anno} \
            ~{"--rd_ri " + rd_ri_anno} \
            ~{"--denovo " + denovo} \
            ~{"--gt " + gt_anno} 

        bgzip ~{prefix}.anno.bed
    >>>
    runtime {
        cpu: select_first([runtime_attr.cpu_cores, default_attr.cpu_cores])
        memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
        disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
        bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
        docker: rdpesr_benchmark_docker
        preemptible: select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
        maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
    }
}