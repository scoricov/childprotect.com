#!/bin/bash


declare -a ARRAY
exec 10<&0
exec < ./js.conf
let count=0

cd ../public/js/

while read LINE; do

    ARRAY[$count]=$LINE
    ((count++))
done

# combine files
cat /dev/null > app.js
cat /dev/null > app.min.js
cat ${ARRAY[@]} >> app.js

# minify combined file
java -jar ../../script/yuicompressor-2.4.7.jar -o app.min.js app.js

exec 0<&10 10<&-
