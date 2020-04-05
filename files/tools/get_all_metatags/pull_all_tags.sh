while read i; do echo "$i" && curl --connect-timeout 30 -L $i | grep "<meta name" >> all_tags.txt ; done < ./seed.txt 2> error_out.txt

# remove the whitespace from the start of lines
sed -i -e 's/^\s*//g' all_tags.txt

#remove pages
sed -i -e 's/^<!DOCTYPE html>.*//g' all_tags.txt

# remove the commented lines
sed -i -e 's/^<!--.*$//' all_tags.txt

# sort tags and remove duplicates
sort -u all_tags.txt > uniq_tags.txt

# make a file with just the names of the tags
cat uniq_tags.txt | sed -e 's/^<meta name=\"//' | sed -e 's/\".*$//' | sort -u > uniq_meta_names.txt

# make a file with the failed connections
cat error_out.txt | grep 'Failed to connect' > connection_failures.txt

# make a file with the 'Could not resolve host' errors
cat error_out.txt | grep 'Could not resolve host' > host_resolve_failures.txt
