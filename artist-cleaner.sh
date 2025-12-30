for f in *.mp3; do
    NEW_ARTIST=$(ffprobe -v error -show_entries format_tags=artist -of default=noprint_wrappers=1:nokey=1 "$f" | cut -d'/' -f1 | cut -d',' -f1)
    ffmpeg -i "$f" -metadata artist="$NEW_ARTIST" -codec copy "temp_$f"
    mv "temp_$f" "$f"
done
