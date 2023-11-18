#!/bin/bash

mkdir -p masks

convert -size 512x512 xc:None masks/blank.png

n_div=8
size=$((512 / 8))

for (( x = 0; x < n_div; ++x )); do
  for (( y = 0; y < n_div; ++y )); do
    cp masks/blank.png masks/mask_${x}_${y}.png
  done
done

for (( x = 0; x < n_div; ++x )); do
  for (( y = 0; y < n_div; ++y )); do

    for (( xx = 0; xx < n_div; ++xx )); do
      for (( yy = 0; yy < n_div; ++yy )); do
        [ $x -eq $xx ] && [ $y -eq $yy ] && continue
        convert masks/mask_${xx}_${yy}.png -draw "rectangle $(( x * size )),$(( y * size )) $(( (x+1) * size )),$(( (y+1) * size ))" masks/mask_${xx}_${yy}_tmp.png
        mv masks/mask_${xx}_${yy}_tmp.png masks/mask_${xx}_${yy}.png
      done
    done

  done
done
