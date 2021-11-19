#Requirements:
# mafft #
# trimal #
# raxml #

##Collect complete BUSCO genes frequency in the dataset##
for file in $(find . -name "full_table.tsv"); do
grep -v "^#" ${file} | awk '$2=="Complete" {print $1}' >> BUSCO_genes.txt;
grep -v "^#" ${file} | awk '$2=="Duplicated" {print $1}' | uniq >> BUSCO_genes.txt;
done

##Collect complete and fragmented BUSCO genes frequency in the dataset##
##Use this piece of code only when you want the phylogeny to be based both on complate and fragmented sequences##
for file in $(find . -name "full_table.tsv"); do
grep -v "^#" ${file} | awk '$2=="Complete" {print $1}' >> BUSCO_genes_frag.txt;
grep -v "^#" ${file} | awk '$2=="Duplicated" {print $1}' | uniq >> BUSCO_genes_frag.txt;
grep -v "^#" ${file} | awk '$2=="Fragmented" {print $1}' >> BUSCO_genes_frag.txt;
done

###Sort above results
#Complete#
sort BUSCO_genes.txt | uniq -c |  sed -e 's/^ *//;s/ /\t/' > BUSCO_genes_count.txt
#Complete + fragmented#
sort BUSCO_genes_frag.txt | uniq -c |  sed -e 's/^ *//;s/ /\t/' > BUSCO_genes_count_frag.txt

##Inspect previous output and manually set value marked as %%%  to print genes for phylogeny analysis##
#Complete#
<BUSCO_genes_count.txt awk -F'\t' '{if($1>=%%%)print$2}' > BUSCO_genes_phylogeny.txt
#Complete + fragmented#
<BUSCO_genes_count_frag.txt awk -F'\t' '{if($1>=%%%)print$2}' > BUSCO_genes_phylogeny_frag.txt

##AA sequneces extraction##
##Assumed naming convention of the main 'BUSCO results' folders as '*_busco', if other please adjust: sed 's/_busco\//:/g' ##
##Important! Extract the fragmented sequences only when neccesarry in the study##

##Extract single-copy sequences##
mkdir busco_aa_single
for dir in $(find . -type d -name "single_copy_busco_sequences")
 do
  sppname=$(dirname $dir | sed 's/_busco\//:/g' | cut -f 1 -d ":" | sed 's/.\///g' );
   for file in ${dir}/*.faa; do
   new_file=$(basename ${file})
   cp $file busco_aa_single/${sppname}_${new_file}
   sed -i 's/^>/>'${sppname}'|/g' busco_aa_single/${sppname}_${new_file}
   cut -f 1 -d ":" busco_aa_single/${sppname}_${new_file} > busco_aa_single/${sppname}_${new_file}.1
   mv busco_aa_single/${sppname}_${new_file}.1 busco_aa_single/${sppname}_${new_file}
done
done
 
##Extract duplicated sequences - important - it uses only the first sequence for a multicopy##
mkdir busco_aa_multi
for dir in $(find . -type d -name "multi_copy_busco_sequences")
 do
  sppname=$(dirname $dir | sed 's/_busco\//:/g' | cut -f 1 -d ":" | sed 's/.\///g' );
   for file in ${dir}/*.faa; do
   new_file=$(basename ${file})
   cp $file busco_aa_multi/${sppname}_${new_file} 2> /dev/null
   sed -i 's/^>/>'${sppname}'|/g' busco_aa_multi/${sppname}_${new_file}  2> /dev/null
   cut -f 1 -d ":" busco_aa_multi/${sppname}_${new_file} > busco_aa_multi/${sppname}_${new_file}.1 2> /dev/null
   mv busco_aa_multi/${sppname}_${new_file}.1 busco_aa_multi/${sppname}_${new_file} 2> /dev/null
   rename 's/\*/non/g' busco_aa_multi/*.faa 2> /dev/null
   rm busco_aa_multi/*non.faa 2> /dev/null
   awk '/^>/{if(N)exit;++N;} {print;}' busco_aa_multi/${sppname}_${new_file} > busco_aa_multi/${sppname}_${new_file}.1 2> /dev/null
   mv busco_aa_multi/${sppname}_${new_file}.1 busco_aa_multi/${sppname}_${new_file} 2> /dev/null
done
done
 
##Extract fragmented sequences##
mkdir busco_aa_fragmented
for dir in $(find . -type d -name "fragmented_busco_sequences")
 do
  sppname=$(dirname $dir | sed 's/_busco\//:/g' | cut -f 1 -d ":" | sed 's/.\///g' );
   for file in ${dir}/*.faa; do
   new_file=$(basename ${file})
   cp $file busco_aa_fragmented/${sppname}_${new_file} 2> /dev/null
   sed -i 's/^>/>'${sppname}'|/g' busco_aa_fragmented/${sppname}_${new_file} 2> /dev/null
   cut -f 1 -d ":" busco_aa_fragmented/${sppname}_${new_file} > busco_aa_fragmented/${sppname}_${new_file}.1 2> /dev/null
   mv busco_aa_fragmented/${sppname}_${new_file}.1 busco_aa_fragmented/${sppname}_${new_file} 2> /dev/null
   rename 's/\*/non/g' busco_aa_fragmented/*.faa 2> /dev/null
   rm busco_aa_fragmented/*non.faa 2> /dev/null
done
done

###Move all files to a single folder - modify this code according to analysis assumptions###
mkdir busco_aa
mv busco_aa_*/*faa busco_aa

###Merge BUSCO genes to single files according to Complete_BUSCO_genes_phylogeny.txt###
##Please adjust "BUSCO_genes_phylogeny.txt" when using the fragmented files as well###
mkdir phylogeny_analysis
while read line; 
do cat busco_aa/*_${line}.faa >> phylogeny_analysis/${line}_aa.fasta; 
done <BUSCO_genes_phylogeny.txt
cd phylogeny_analysis
ls *.fasta | sed 's/_aa.fasta//g' > prefix_phylogeny.txt

###Generate alignment files, please adjust the thread number### 
while read PREFIX
do
mafft --thread 100 --auto  ${PREFIX}_aa.fasta > ${PREFIX}_aa.aln
trimal -automated1 -in ${PREFIX}_aa.aln -out ${PREFIX}_filt_aa.aln
cut -f 1 -d "|" ${PREFIX}_filt_aa.aln > ${PREFIX}_filt_aa.aln.trimmed
done < prefix_phylogeny.txt

##Concatenate aligment for each gene to a single superalignment with superalignment.py ##
##Download from: https://gitlab.com/kjsnavely/busco_usecases/-/tree/master/phylogenomics## 
python3 superalignment.py ./

##(Optional) Rename the supermatrix file - replace: %%%##
rename 's/supermatrix/%%%/' supermatrix.aln.faa

##(Optional)If you want to remove gaps from the supermatrix file, adjust its level with altering -gt parameter (0-1)###
##Example: -gt 0.95 will remove an column for an alignment when gaps >5% ### 
trimal -in supermatrix.aln.faa -out supermatrix.95.aln.faa -gt 0.95

##Generate maximum  likelihood tree, plase adjust ALL parameters###
#Example: raxmlHPC-PTHREADS-SSE3 -T 220 -f a -m PROTGAMMAJTT -N 100 -n oomycota_284 -s supermatrix_oomytoca.aln.faa -p 2137 -x 20405
raxmlHPC-PTHREADS-SSE3 -T #### -f a -m PROTGAMMAJTT -N ### -n #### -s ### -p ### -x ###
