##########################################################################################################################################
####                                                                                                                                  ####
###                                                                                                                                    ###
##                                                                                                                                      ##
#                                              1.Query_CMap                                                                               #
##                                                                                                                                      ##
###                                                                                                                                    ###
####                                                                                                                                  ####
##########################################################################################################################################

## AUTHOR: HAMEL PATEL
## EMAIL: Hamel.patel@kcl.ac.uk
## DATE: 06/02/2019 

##### DESCRIPTION OF ANALYSIS ####
## 5 METHODS HAVE BEEN IMPLIMENTED TO QUERY CMAP. This script will impliment all 3 methods. 
##
## Dataset: AsymAD frontal cortex
## 
##
## change following depending on which
## RRHO.test <-  RRHO(datasetmerge, query_sig, BY=TRUE, alternative='enrichment') # for version 1.1.0
## RRHO.test <-  RRHO(datasetmerge, query_sig, BY=TRUE)
##
##
##

##### SET PARAMETERS #####

rm(list=ls())

options=(stringAsFactors=FALSE)

Dataset="AsymAD_FC"

##### LIBRARY #####

library(WGCNA)
library(RRHO)
library(foreach)
library(doParallel)
library(SPIA)

##### SET DIRECTORIES ####

# working directory
work_dir="/media/hamel/Workspace/Dropbox/Projects/CMap2/5.AD_data/5.1.AsymAD"

# directory of DE results of disease
data_dir="/media/hamel/Workspace/Dropbox/Projects/CMap2/5.AD_data/5.1.AsymAD"

# directory to methods to query cmap
cmap_data_dir="/media/hamel/Workspace/Dropbox/Projects/CMap2/3.Method_development"

# directory for processed cmap data
HT_HG_U133A_MCF7_dir<-"/media/hamel/Workspace/Dropbox/Projects/CMap2/1.Data/3.HT_HG_U133A_MCF7_processing/DE_results"

# directory for SPIA
cmap_spia<-"/media/hamel/Workspace/Dropbox/Projects/CMap2/3.Method_development/5.with_pathway_knowledge"

### this point onwards is automated

setwd(work_dir)

#create directory ofr results
dir.create("Results")

results_dir=paste(work_dir, "Results", sep="/")

##### LOAD QUERY DE RESULTS #####
setwd(data_dir)

disease_DE<-read.csv("Frontal_Cortex_CO_AD_v_CO_DE_results.txt", row.names=1)

head(disease_DE)

##### METHOD 1 - BI-DIRECTIONAL ENRICHMENT METHOD #####

# load cmap query database
setwd(cmap_data_dir)
load("1.single_drug_bi_directional_enrichment/cmap_database_for_bi_directional_enrichment_search.Rdata")
cmap_database_method1<-subset_CMap
rm(subset_CMap)

# create cmap lis of genes
cmap_database_method1_genes<-rownames(cmap_database_method1[[1]])
# add "UP" and "DOWN" name to gene list
cmap_database_method1_genes<-c(paste(cmap_database_method1_genes, "DOWN", sep = "_"), paste(cmap_database_method1_genes, "UP", sep = "_"))
# check
head(cmap_database_method1_genes)
tail(cmap_database_method1_genes)
length(cmap_database_method1_genes)

# create function for method 1
setwd(work_dir)

run_method1<-function(full_DE_results) {
  #extract sig results - keeping rownames only (Entrez ID)
  sig_DEG_up<-rownames(subset(full_DE_results, logFC>0 & adj.P.Val<=0.05))
  sig_DEG_down<-rownames(subset(full_DE_results, logFC<0 & adj.P.Val<=0.05))
  
  #append "UP" and "DOWN" to relevant DE results
  sig_DEG_up<-paste(sig_DEG_up, "UP", sep="_")
  sig_DEG_down<-paste(sig_DEG_down, "DOWN", sep="_")
  
  #write file
  write(c("query_signature", sig_DEG_up, sig_DEG_down), sep="\n", "query_signature.txt")
  
  #create empty list to store Temporal_lobe_results
  cmap_results<-list()
  
  # for each drug 
  
  for (x in 1:length(names(cmap_database_method1))){
    #reverse up + down coding for significant drug genes
    drug_sig_up<-paste(rownames(subset(cmap_database_method1[[x]], adj.P.Val<=0.05 & logFC > 0)), "DOWN", sep="_")
    drug_sig_down<-paste(rownames(subset(cmap_database_method1[[x]], adj.P.Val<=0.05 & logFC < 0)), "UP", sep="_")
    #specify which genes in "cmap_database_method1_genes" are significant up/down in drug - create categories object
    categories<-cmap_database_method1_genes
    for (y in 1:length(categories)){
      if (categories[y]%in%drug_sig_up==T) {
        categories[y]<-"sig"
      }
      else if (categories[y]%in%drug_sig_down==T) {
        categories[y]<-"sig"
      }
      else{
        categories[y]<-"background"
      }
    }
    #run enrichment test
    temp_results = userListEnrichment(
      # full gene list CMap - per drug
      geneR=cmap_database_method1_genes, 
      # assign significant and background genes
      labelR=categories, 
      # query llist - brain region genes
      fnIn="query_signature.txt",
      catNmIn=names(cmap_database_method1[x]))
    #save temp_results
    cmap_results[[x]]<-temp_results
    #save name of drug
    names(cmap_results)[x]<-names(cmap_database_method1[x])
  }
  
  #copy names of drugs to results
  names(cmap_results)[1]<-names(cmap_database_method1[1])
  
  # summarise results - drug name, total number of DEG, DEG overlp, p val
  
  drug_results_table<-as.data.frame(names(cmap_results))
  colnames(drug_results_table)[1]<-"Drug_name"
  drug_results_table$total_DEG_count<-0
  drug_results_table$DEG_Overlap<-0
  drug_results_table$P_val<-0
  
  for (x in 1:length(names(cmap_results))){
    #get number of DEG per drug
    drug_sig_up<-rownames(subset(cmap_database_method1[[x]], adj.P.Val<=0.05 & logFC > 0))
    drug_sig_down<-rownames(subset(cmap_database_method1[[x]], adj.P.Val<=0.05 & logFC < 0))
    drug_results_table$total_DEG_count[x]<-length(c(drug_sig_up, drug_sig_down))
    drug_results_table$DEG_Overlap[x]<-dim(as.data.frame(cmap_results[[x]]$ovGenes))[1]
    drug_results_table$P_val[x]<-(cmap_results[[x]]$pValues)$Pvalues
  }
  
  #order dataframe
  drug_results_table<-drug_results_table[order(drug_results_table$P_val),]
  rownames(drug_results_table)<-1:dim(drug_results_table)[1]
  head(drug_results_table)
  
  return(drug_results_table)
  
}

#apply function
method1_results<-run_method1(disease_DE)

#check results
head(method1_results)

#FDR adjust
method1_results$FDR_adj_P_val<-p.adjust(method1_results$P_val, method = "fdr")

# output results table

setwd(results_dir)

write.table(method1_results, paste(Dataset,"bi-directional_results_table_method1.txt", sep="_"), quote=F, sep="\t")

##### METHOD 2 - SIMPLE ANTI CORRELATION METHOD #####

# load cmap query database
setwd(cmap_data_dir)
cmap_database_method2<-read.table("3.single_drug_anti_correlation/cmap_query_database_method2.txt", check.names = F)
head(cmap_database_method2)[1:5]

# create function
run_method2<-function(full_DE_results) {
  #extract sig genes
  sig_DEG_up<-(subset(full_DE_results, logFC>0 & adj.P.Val<=0.05))[1]
  sig_DEG_down<-(subset(full_DE_results, logFC<0 & adj.P.Val<=0.05))[1]
  
  # change logFC to -1 for up-regulated and +1 for down regulated - anti-correlation
  sig_DEG_up$logFC<--1
  sig_DEG_down$logFC<-1
  
  #merge list
  query_sig<-rbind(sig_DEG_up, sig_DEG_down)
  
  #merge query signature and cmap by common probes
  correlation_input<-merge(query_sig, cmap_database_method2, by="row.names")
  rownames(correlation_input)<-correlation_input$Row.names
  correlation_input$Row.names<-NULL
  
  # run correlation test
  correlation_results<-apply(correlation_input,2, function(x) cor.test(x, correlation_input$logFC, method="spearman", exact=F))
  
  # merge results into dataframe
  correlation_results_dataframe<-as.data.frame(sapply(correlation_results, "[[", "p.value"))
  colnames(correlation_results_dataframe)<-"P_val"
  correlation_results_dataframe$Drug<-rownames(correlation_results_dataframe)
  correlation_results_dataframe<-correlation_results_dataframe[order(correlation_results_dataframe$P_val) ,]
  correlation_results_dataframe<-correlation_results_dataframe[-1,]
  rownames(correlation_results_dataframe)<-1:dim(correlation_results_dataframe)[1]
  correlation_results_dataframe<-correlation_results_dataframe[c(2,1)]
  return(correlation_results_dataframe)
  
}

#apply function
method2_results<-run_method2(disease_DE)

# check results
head(method2_results)

#FDR adj
method2_results$FDR_adj_P_val<-p.adjust(method2_results$P_val, method = "fdr")

# check results
head(method2_results)

# output results table

setwd(results_dir)

write.table(method2_results, paste(Dataset, "anti_correlation_results_table_method2.txt", sep="_"), quote=F, sep="\t")

##### METHOD 3 - GSEA - RRHO METHOD #####

#load cmap data

setwd(HT_HG_U133A_MCF7_dir)
load("full_DE_results.Rdata")
full_cmap_DE_results<-full_DE_results

# create function
run_method3<-function(full_DE_results, cores) {
  
  # REFINE QUERY SIGNATURE
  sig_DEG_up<-(subset(full_DE_results, logFC>0 & adj.P.Val<=0.05))[c(1,7)]
  sig_DEG_down<-(subset(full_DE_results, logFC<0 & adj.P.Val<=0.05))[c(1,7)]
  # change logFC 1 for up regulated genes and -1 for down regulated genes
  sig_DEG_up$logFC<-1
  sig_DEG_down$logFC<--1
  #rank - most sig up gene will be top
  sig_DEG_up$rank<-rank(1-sig_DEG_up$adj.P.Val)
  #reverse - rank - most sig down gene will be bottom
  sig_DEG_down$rank<--rank(1-sig_DEG_down$adj.P.Val)
  #merge up/down list
  query_sig<-rbind(sig_DEG_up, sig_DEG_down)
  # copy rownames to ne column
  query_sig$Entrez_Gene_ID<-rownames(query_sig)
  # assign new rank - highest rank is most sig up gene, lowest rank is sig down gene, middle is where genes not changed much
  query_sig$true_rank<-rank(query_sig$rank, ties.method = "min")
  #re-arrange by ture rank
  query_sig<-query_sig[order(-query_sig$true_rank),]
  #remove unwanted columns
  query_sig$logFC<-NULL
  query_sig$adj.P.Val<-NULL
  query_sig$rank<-NULL
  #change colname
  colnames(query_sig)[2]<-"Rank"
  #asign rownames
  rownames(query_sig)<-1:nrow(query_sig)
  
  # setup cluster
  #no_cores <- detectCores() - 2
  registerDoParallel(cores)
  
  # RUN RRHO USING PARALLEL PROCESSING
  
  RRHO_results<-foreach (x=1:length(names(full_cmap_DE_results)),
                         .verbose=T,
                         .packages="WGCNA", 
                         .combine=rbind) %dopar% {
                           dataset<-subset(full_cmap_DE_results[[x]], rownames(full_cmap_DE_results[[x]]) %in% query_sig$Entrez_Gene_ID)
                           # keep only logFC and P.Value columns
                           dataset<-dataset[grep("logFC|adj.P.Val", colnames(dataset))]
                           #subset to up/down
                           datasetup<-subset(dataset, logFC>0)
                           datasetdown<-subset(dataset, logFC<0)
                           # reverse rank to query - give up regulated genes negative value and down regulated positive rank
                           datasetdown$rank<-rank(1-datasetdown$adj.P.Val)
                           #rank - most sig down genes ranked lowest (using negative ranking)
                           datasetup$rank<--rank(1-datasetup$adj.P.Val)
                           # merge up/down list
                           datasetmerge<-rbind(datasetup, datasetdown)
                           # assign new rank - highest rank is most sig up gene, lowest rank is sig down gene, middle is where genes not changed much
                           datasetmerge$true_rank<-rank(datasetmerge$rank, ties.method = "min")
                           #rearrgae by ture rank
                           datasetmerge<-datasetmerge[order(-datasetmerge$true_rank),]
                           #remove unwanted columns
                           datasetmerge$logFC<-NULL
                           datasetmerge$adj.P.Val<-NULL
                           datasetmerge$rank<-NULL
                           #add Entrez_id
                           datasetmerge$Entrez_Gene_ID<-rownames(datasetmerge)
                           #rearrange columns
                           datasetmerge<-datasetmerge[c(2,1)]
                           #change colname
                           colnames(datasetmerge)[2]<-"Rank"
                           #asign rownames
                           rownames(datasetmerge)<-1:nrow(datasetmerge)
                           #RRHO object
                           RRHO.test <-  RRHO(datasetmerge, query_sig, BY=TRUE, alternative='enrichment')
                           #RRHO.test <-  RRHO(datasetmerge, query_sig, BY=TRUE)
                           RRHO_results<-pvalRRHO(RRHO.test, 1000)
                           return(RRHO_results$pval)
                           gc()}
  
  #close cluster
  stopImplicitCluster()
  gc()
  
  # create results table- and arrange by p_val
  RRHO_results_table<-as.data.frame(unlist(RRHO_results))
  RRHO_results_table$Drug_names<-names(full_cmap_DE_results)
  colnames(RRHO_results_table)[1]<-"P_Val"
  RRHO_results_table<-RRHO_results_table[order(RRHO_results_table$P_Val),]
  rownames(RRHO_results_table)<-1:nrow(RRHO_results_table)
  RRHO_results_table<-RRHO_results_table[c(2,1)]                        
  
  #return results
  
  return(RRHO_results_table)
  
}

#apply function
method3_results<-run_method3(disease_DE, 20)


# check results
head(method3_results)

# output results table

setwd(results_dir)

write.table(method3_results, paste(Dataset, "RRHO_results_method3.txt", sep="_") , quote=F, sep="\t")

##### METHOD 4 - BI-DIRECTIONAL ENRICHMENT METHOD - *** DRUG COMBINATION *** ####

#load drug combination database - drug database has "UP" appended to down regulated genes and vice-versa
setwd(cmap_data_dir)
load("2.2.combined_drug_bi-directional_enrichment/Drug_combination_database.Rdata")
setwd(work_dir)

# using list of genes in cmap from method 1 - has "UP", "DOWN" appended to each gene
head(cmap_database_method1_genes)
tail(cmap_database_method1_genes)
length(cmap_database_method1_genes)

#create function
run_method4<-function(full_DE_results, cores) {
  
  #extract sig results - keeping rownames only (Entrez ID)
  sig_DEG_up<-rownames(subset(full_DE_results, logFC>0 & adj.P.Val<=0.05))
  sig_DEG_down<-rownames(subset(full_DE_results, logFC<0 & adj.P.Val<=0.05))
  
  #append "UP" and "DOWN" to relevant DE results
  sig_DEG_up<-paste(sig_DEG_up, "UP", sep="_")
  sig_DEG_down<-paste(sig_DEG_down, "DOWN", sep="_")
  
  #write file
  write(c("query_signature", sig_DEG_up, sig_DEG_down), sep="\n", "query_signature_method4.txt")
  
  #create empty list to store Temporal_lobe_results
  cmap_results<-list()
  
  # setup cluster
  #no_cores <- detectCores() - 2
  registerDoParallel(cores)
  
  # for each drug 
  cmap_results<-foreach(x=1:length(names(Drug_combination_database)),
                        .verbose=T,
                        .packages="WGCNA",
                        .combine=rbind) %dopar% {
                          #specify which genes in "cmap_database_method1_genes" are significant up/down in drug - create categories object
                          categories<-cmap_database_method1_genes
                          for (y in 1:length(categories)){
                            if (categories[y]%in%Drug_combination_database[[x]]==T) {
                              categories[y]<-"sig"
                            }
                            else{
                              categories[y]<-"background"
                            }
                          }
                          #run enrichment Drug_combination_database
                          temp_results = userListEnrichment(
                            # full gene list CMap - per drug
                            geneR=cmap_database_method1_genes, 
                            # assign significant and background genes
                            labelR=categories, 
                            # query list - 
                            fnIn="query_signature_method4.txt",
                            catNmIn=names(Drug_combination_database[x]))
                          return(temp_results)
                          gc()
                        }
  
  #close cluster
  stopImplicitCluster()
  
  #add drug name
  for (x in 1:length(names(Drug_combination_database))) {
    names(cmap_results)[x]<-names(Drug_combination_database)[x]
  }
  
  # summarise temp_results - drug name, total number of DEG, DEG overlp, p val
  
  drug_results_table<-as.data.frame(names(cmap_results))
  colnames(drug_results_table)[1]<-"Drug_name"
  drug_results_table$total_DEG_count<-0
  drug_results_table$DEG_Overlap<-0
  drug_results_table$P_val<-0
  
  for (x in 1:length(names(Drug_combination_database))){
    #get number of DEG per drug
    drug_results_table$total_DEG_count[x]<-length(Drug_combination_database[[x]])
    drug_results_table$DEG_Overlap[x]<-cmap_results[[x]]$NumOverlap
    drug_results_table$P_val[x]<-cmap_results[[x]]$Pvalues
  }
  
  #order dataframe
  drug_results_table<-drug_results_table[order(drug_results_table$P_val),]
  rownames(drug_results_table)<-1:dim(drug_results_table)[1]
  
  #return dataframe
  return(drug_results_table)
}

#apply function
method4_results<-run_method4(disease_DE, 10)

#remove excess blank rows
method4_results<-subset(method4_results, total_DEG_count!=0)

#rename rownames
rownames(method4_results)<-1:dim(method4_results)[1]

# check results
head(method4_results)

# output results table

setwd(work_dir)

write.table(method4_results, paste(Dataset, "bi-directional_drug_combination_results_method4.txt", sep="_") , quote=F, sep="\t")

##### METHOD 5 - PATHWAY BASED #####

setwd(cmap_spia)

#load spia database
load("CMap_SPIA_subset_to_sig.Rdata")

## RUN SPIA ON DISEASE
sig_DEG<-subset(disease_DE, adj.P.Val<=0.05)
#print number of DEG
print(paste("Number of significant DEG's =", nrow(disease_DE)))
#create spia input
sig_DEG_SPIA_format<-sig_DEG$logFC
names(sig_DEG_SPIA_format)<-as.vector(rownames(sig_DEG))
#run SPIA
SPIA_results<-spia(de=sig_DEG_SPIA_format, all=rownames(disease_DE), organism="hsa", plots=F)
# susbet sig pathways
SPIA_results_sig_only<-subset(SPIA_results, pG<=0.05)
# print number of sig pathways
print(paste("Number of significant pathways =", nrow(SPIA_results_sig_only)))
#create reverse status (Inhibited==Activated, Activated==Inhibited)
SPIA_results_sig_only$rev_status<-"temp"
for (x in 1:nrow(SPIA_results_sig_only)){
  if (SPIA_results_sig_only$Status[x]=="Activated"){
    SPIA_results_sig_only$rev_status[x]<-"Inhibited"
  }
  else {
    SPIA_results_sig_only$rev_status[x]<-"Activated"
  }
}


## CALCULATE P VALUES FOR EACH DRUG

# hypergeometric test using phyper
# phyper=(overlap-1,list1,PopSize-list1,list2,lower.tail = FALSE, log.p = FALSE)
# overlap-1 = number of pathways corrected by drug in disease
# list1 = number of sig pathways in disease
# PopSize = Number of possible pathways (139) * activation/inhibition possibility (2) = 278. 
# list2 = number of sig pathways in Drug
#
#

# number of sig pathways in disease
list1<-nrow(SPIA_results_sig_only)

# number of possible pathways
PopSize<-278

#empty dataframe with drug names
method5_results<-data.frame(names(cmap_SPIA_sig))  
colnames(method5_results)<-"Drug"

#column for number of pathways corrected
method5_results$pathways_corrected<-0

# column for p values
method5_results$P_value<-1


# calculate p-values
for (drug in 1:length(cmap_SPIA_sig)) {
  # number of sig patahway in drug
  list2<-nrow(cmap_SPIA_sig[[drug]])
  # pathway activation/inhibition in disease
  disease_pathway<-paste(SPIA_results_sig_only$Name, SPIA_results_sig_only$rev_status, sep="_")
  # pathway activation/inhibiton in drug
  drug_pathway<-paste(cmap_SPIA_sig[[drug]]$Name, cmap_SPIA_sig[[drug]]$Status, sep="_")
  # number of overlapping pathway in drug and disease
  overlap<-length(intersect(drug_pathway, disease_pathway))
  # write number of pathways corrected
  method5_results[drug,2]<-overlap
  # calculate p value
  p_value<-phyper((overlap-1), list1, (PopSize-list1) , list2, lower.tail=F, log.p=F)
  # assign p_value to drug
  method5_results[drug,3]<-p_value
}

# sort results table by p-value
method5_results<-method5_results[order(method5_results$P_value),]
rownames(method5_results)<-1:nrow(method5_results)
nrow(subset(method5_results, P_value<=0.05))
subset(method5_results, P_value<=0.05)

head(method5_results)

# output results table

setwd(results_dir)

write.table(method5_results, paste(Dataset, "pathway_based_results_method5.txt", sep="_") , quote=F, sep="\t")

##### CHECK RESULTS #####
head(method1_results, 10)
nrow(subset(method1_results, method1_results$FDR_adj_P_val<0.05))
method1_results[grep("memantine|galantamine", method1_results$Drug_name),]


head(method2_results, 10)
nrow(subset(method2_results, method2_results$FDR_adj_P_val<0.05))
method2_results[grep("memantine|galantamine", method2_results$Drug),]


head(method3_results, 10)
nrow(subset(method3_results, method3_results$P_Val<0.05))
method3_results[grep("memantine|galantamine", method3_results$Drug_name),]


head(method5_results, 10)
nrow(subset(method5_results, method5_results$P_value<0.05))
method5_results[grep("memantine|galantamine", method5_results$Drug),]

# common drug in method 3 + 4

as.data.frame(table(c(as.character(subset(method1_results, method1_results$FDR_adj_P_val<0.05)[,1]),
                      as.character(subset(method2_results, method2_results$FDR_adj_P_val<0.05)[,1]),
                      as.character(subset(method3_results, method3_results$P_Val<0.05)[,1]), 
                      as.character(subset(method5_results, method5_results$P_value<0.05)[,1]))))

##### MERGE RESULTS WITH DISEASE_DRUG MAPPING #####

head(method1_results)
head(method2_results)
head(method3_results)
head(method5_results)

#load TTD database

TTD<-read.csv("/media/hamel/Workspace/Dropbox/Projects/CMap2/2.CMap_drug_disease_association/cmap_drug_disease_mapping.txt", sep="\t")

head(TTD)

TTD<-TTD[c(2,4)]

# standardise results

colnames(method1_results)[1]<-"drug_conc"
colnames(method2_results)[1]<-"drug_conc"
colnames(method3_results)[1]<-"drug_conc"
colnames(method5_results)[1]<-"drug_conc"


method1_results<-merge(method1_results, TTD, by="drug_conc", all.x =T) 
method2_results<-merge(method2_results, TTD, by="drug_conc", all.x =T) 
method3_results<-merge(method3_results, TTD, by="drug_conc", all.x =T) 
method5_results<-merge(method5_results, TTD, by="drug_conc", all.x =T) 

dim(method1_results)
dim(method2_results)
dim(method3_results)
dim(method5_results)

# sort
method1_results<-method1_results[order(method1_results$FDR_adj_P_val),]
method2_results<-method2_results[order(method2_results$FDR_adj_P_val),]
method3_results<-method3_results[order(method3_results$P_Val),]
method5_results<-method5_results[order(method5_results$P_value),]



head(method1_results, 10)
nrow(subset(method1_results, method1_results$FDR_adj_P_val<0.05))
method1_results[grep("memantine|galantamine|tacrine", method1_results$drug_conc),]


head(method2_results, 10)
nrow(subset(method2_results, method2_results$FDR_adj_P_val<0.05))
method2_results[grep("memantine|galantamine|tacrine", method2_results$drug_conc),]


head(method3_results, 10)
nrow(subset(method3_results, method3_results$P_Val<0.05))
method3_results[grep("memantine|galantamine|tacrine", method3_results$drug_conc),]


head(method5_results, 10)
nrow(subset(method5_results, method5_results$P_value<0.05))
method5_results[grep("memantine|galantamine|tacrine", method5_results$drug_conc),]

# common drug in method 3 + 4

as.data.frame(table(c(as.character(subset(method1_results, method1_results$FDR_adj_P_val<0.05)[,1]),
                      as.character(subset(method2_results, method2_results$FDR_adj_P_val<0.05)[,1]),
                      as.character(subset(method3_results, method3_results$P_Val<0.05)[,1]), 
                      as.character(subset(method5_results, method5_results$P_value<0.05)[,1]))))



##### SAVE #####

setwd(work_dir)

#save.image("1.QUERY_CMAP.Rdata")
