#!/bin/bash
# (c) 2010 Dustin L. Howett <dustin@howett.net>
# Public Domain (though I would /love/ to know if you found this useful!)
#
##############################
# Format for a basic DiffIndex
# SHA1-Current: [sha1 of current Packages] [size of current Packages]
# SHA1-History:
#  [sha1 of a Packages from some point in time] [size] [Patch to apply to move to the next step]
# SHA1-Patches:
#  [sha1 of a Patch] [size] [Patch name]

diffname=$(date +%Y-%m-%d-%H%M.%S)
mkdir -p Packages.diff

diff --ed Packages.old Packages > Packages.diff/$diffname
if [ $? -eq 0 ]; then
	echo No Changes >&2
	rm Packages.diff/$diffname
	exit 0
fi

# Store the old SHA1 and Size for the new SHA1-History entry.
oldsha1=$(md5sum Packages.old | cut -d' ' -f1)
oldsize=$(stat -f "%z" Packages.old)

# Store the new SHA1 and Size for the SHA1-Current entry.
newsha1=$(md5sum Packages | cut -d' ' -f1)
newsize=$(stat -f "%z" Packages)

# Store the patch SHA1 and Size for the SHA1-Patches entry.
diffsha1=$(md5sum Packages.diff/$diffname | cut -d' ' -f1)
diffsize=$(stat -f "%z" Packages.diff/$diffname)

# Arrays to store SHA1-History and SHA1-Patches entries
declare -a history_sha1s history_sizes history_names
numhists=0
declare -a patch_sha1s patch_sizes patch_names
numpats=0

if [ -e Packages.diff/Index ]; then
	mode="nil"
	OIFS="$IFS"
	IFS=""
	re="^\s+([a-f0-9]+)\s+([0-9]+)\s+(.*)" # Fuck bash, you have to store the regex in a variable if you want it to be anywhere near "complex"?
	while read line; do
		if [[ "$line" =~ ^SHA1-History ]]; then
			mode="hist";
		elif [[ "$line" =~ ^SHA1-Patches ]]; then
			mode="pat";
		elif [[ "$line" =~ $re ]]; then
			if [[ "$mode" == "hist" ]]; then
				history_sha1s[$numhists]=${BASH_REMATCH[1]}
				history_sizes[$numhists]=${BASH_REMATCH[2]}
				history_names[$numhists]=${BASH_REMATCH[3]}
				let "numhists++";
			elif [[ "$mode" == "pat" ]]; then
				patch_sha1s[$numpats]=${BASH_REMATCH[1]}
				patch_sizes[$numpats]=${BASH_REMATCH[2]}
				patch_names[$numpats]=${BASH_REMATCH[3]}
				let "numpats++";
			fi
		fi
	done < Packages.diff/Index
	IFS="$OIFS"
fi

# Append our newest entry to SHA1-History and SHA1-Patches
history_sha1s[$numhists]=$oldsha1
history_sizes[$numhists]=$oldsize
history_names[$numhists]=$diffname
let "numhists++";
patch_sha1s[$numpats]=$diffsha1
patch_sizes[$numpats]=$diffsize
patch_names[$numpats]=$diffname
let "numpats++";

# Generate the new DiffIndex containing the new Packages info, History entry and Patch.
echo "SHA1-Current: $newsha1 $newsize" > Packages.diff/Index.new
echo "SHA1-History:" >> Packages.diff/Index.new
for i in ${!history_sha1s[@]}; do
	echo " ${history_sha1s[i]} ${history_sizes[i]} ${history_names[i]}" >> Packages.diff/Index.new
done
echo "SHA1-Patches:" >> Packages.diff/Index.new
for i in ${!patch_sha1s[@]}; do
	echo " ${patch_sha1s[i]} ${patch_sizes[i]} ${patch_names[i]}" >> Packages.diff/Index.new
done

# We made it here? Seamlessly replace Packages and the DiffIndex.
mv Packages.diff/Index.new Packages.diff/Index
gzip -9 Packages.diff/$diffname