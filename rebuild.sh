#!/bin/bash
cd ~/Projects/nito/public_html/electra

# Remove the old MD5Sums
sed -e '/^MD5Sum/,$d' Release > Release.new

# Regenerate Packages
dpkg-scanpackages -m ./deb > Packages.new

# Get info about Packages and compress it
nsize=$(stat -f "%z" Packages.new)
nsum=$(md5sum Packages.new | cut -d' ' -f1)
bzip2 -c Packages.new > Packages.bz2.new
ncsize=$(stat -f "%z" Packages.bz2.new)
ncsum=$(md5sum Packages.bz2.new | cut -d' ' -f1)

# Write the new MD5Sums
cat >> Release.new << _E
MD5Sum:
 ${nsum} ${nsize} Packages
 ${ncsum} ${ncsize} Packages.bz2
_E

# Sign it
gpg --no-use-agent --passphrase-file passphrase --yes -abs -o Release.gpg.new Release.new

#gpg -abs -o Release.gpg.new Release.new

# Move new files into place.
cp Packages Packages.old
mv Packages.new Packages
mv Packages.bz2.new Packages.bz2
mv Release.gpg.new Release.gpg
mv Release.new Release

# Generate diff indices
./diffindex.sh
#rm Packages.old