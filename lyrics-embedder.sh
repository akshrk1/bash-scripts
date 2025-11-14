#!/bin/bash
shopt -s nullglob
for mp3_file in *.mp3; do
    lrc_file="${mp3_file%.*}.lrc"
    if [[ -f "$lrc_file" ]]; then
        echo "embedding lyrics for: $mp3_file"
        eyeD3 --remove-all-comments --add-lyrics="$lrc_file" "$mp3_file"
        if [[ $? -eq 0 ]]; then
            echo "done with $mp3_file"
        else
            echo "failed on $mp3_file"
        fi
    else
        echo "no .lrc file found for $mp3_file, skipping . . . "
    fi
done
shopt -u nullglob

echo "-----------------------------"
echo "end of directory - all files processed."
echo "-----------------------------"

