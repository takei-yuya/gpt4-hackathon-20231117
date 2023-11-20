#!/bin/bash

set -uex

. .env

mkdir -p output
convert "${1}" -crop "512x512^" -gravity center +repage cropped.png
cp cropped.png output/image_0.png
declare -i i=0
for mask in $(ls -1 masks/mask_*_*.png | sort -R); do
  echo "${mask}"
  curl https://api.openai.com/v1/images/edits \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "OpenAI-Organization: $OPENAI_ORG_KEY" \
    -F image="@output/image_$((i)).png" \
    -F mask="@${mask}" \
    -F prompt="A ship" \
    -F size=512x512 \
    -o tmp.json
  cat tmp.json
  curl -o "output/image_$((i + 1)).png" "$(jq -r ".data[0].url" tmp.json)"
  i+=1
done
