cp $1 $1.edbak
jq . $1 > tmp.json
vim tmp.json
cp tmp.json $1
