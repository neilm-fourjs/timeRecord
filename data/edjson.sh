cp $1 $1.bak
jq . $1 > tmp.json
vim tmp.json
cp tmp.json $1
