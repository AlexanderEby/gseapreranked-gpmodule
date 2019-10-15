# Copyright (c) 2003-2018 Broad Institute, Inc., Massachusetts Institute of Technology, and Regents of the University of California.  All rights reserved.
#!/bin/sh
execDir=`dirname $0`

zip1=$1
zip2=$2

base1=`basename $1`
base2=`basename $2`
bare1=${base1%%.zip}
bare2=${base2%%.zip}
diffDir1=`mktemp -d $bare1.XXXXXX`
diffDir2=`mktemp -d $bare2.XXXXXX`

unzip -q $zip1 -d $diffDir1
unzip -q $zip2 -d $diffDir2

# Diff only selected files out of the ZIP
diff -i --strip-trailing-cr -q $diffDir1/edb/$bare1.rnk $diffDir2/edb/$bare2.rnk
status=$?
diff -i --strip-trailing-cr -q $diffDir1/edb/results.edb $diffDir2/edb/results.edb
status=$(( $? + status ))

# The generated GMT files sometimes have a different order when there are multiple GMT inputs.
# This should probably be changed in the long run, but for now we just compare the sorted outputs.
# This does *NOT* happen with "regular" GSEA so this script differs at this point.
sort $diffDir1/edb/gene_sets.gmt > $diffDir1/edb/sorted.matrix
sort $diffDir2/edb/gene_sets.gmt > $diffDir2/edb/sorted.matrix

diff -i --strip-trailing-cr -q $diffDir1/edb/sorted.matrix $diffDir2/edb/sorted.matrix
status=$(( $? + status ))

# Checking existence of report files.  We're working out of diffDir1 as that is from the 'expected' result
# For XLS, just check that the same files are present in both as comparing contents is not robust.
# Note: we exclude certain files as they contain numeric timestamps.  It might be possible to clean those up
#       but for now the test is sufficient without them.
binFileList=`ls -1 $diffDir1/*.xls| grep -v 'gsea_report_.*.xls'| grep -v 'ranked_gene_list_.*.xls'`
for binFile in $binFileList; do
   baseBinFile=`basename $binFile`
   if [ -s $diffDir2/$baseBinFile ]; then
      diff -i --strip-trailing-cr -q $binFile $diffDir2/$baseBinFile
      status=$(( $? + status ))
   else
      status=$(( 1 + status ))
   fi
done

# For images, we diff the contents of any SVGs since it's just a simple file compare.  We've decided not to
# deal with PNG comparisons as it's too resource-intensive and prone to per-machine variation.
svgFileList=`ls -1 $diffDir1/*.svg.gz`
for svgFile in $svgFileList; do
   baseSvgFile=`basename $svgFile`
   if [ -s $diffDir2/$baseSvgFile ]; then
      zdiff -i --strip-trailing-cr -q $svgFile $diffDir2/$baseSvgFile
      status=$(( $? + status ))
   else
      status=$(( 1 + status ))
   fi
done

# For HTML we can diff the contents.  As above, excluding certain files containing numeric timestamps.
htmlFileList=`ls -1 $diffDir1/*.html | grep -v 'gsea_report_.*.html' | grep -v 'index.html'`
for htmlFile in $htmlFileList; do
   baseHtmlFile=`basename $htmlFile`
   #diff -b -i --strip-trailing-cr -q $diffDir1/${baseHtmlFile} $diffDir2/${baseHtmlFile}
   # Clean up possible PNG file naming differences.  This is useful for comparing against GUI runs but makes no difference with CLI/GpUnit runs.
   sed 's/_[0-9]*.png/.png/g' < $htmlFile > $diffDir1/cln_${baseHtmlFile}
   sed 's/_[0-9]*.png/.png/g' < $diffDir2/$baseHtmlFile > $diffDir2/cln_${baseHtmlFile}
   diff -b -i --strip-trailing-cr -q $diffDir1/cln_${baseHtmlFile} $diffDir2/cln_${baseHtmlFile}
   status=$(( $? + status ))
done

rm -rf $diffDir1 $diffDir2
exit $status
