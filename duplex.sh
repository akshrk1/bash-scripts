#!/usr/bin/env bash

if ! command -v zenity >/dev/null; then
    echo "Zenity is required."
    exit 1
fi

if [ -n "$1" ]; then
    INPUT="$1"
else
    INPUT=$(zenity --file-selection \
        --title="Select PDF to Print" \
        --file-filter="PDF files (*.pdf) | *.pdf")
fi

if [ -z "$INPUT" ]; then
    zenity --error --text="No PDF selected."
    exit 1
fi

WORKDIR=$(mktemp -d)
trap "rm -rf $WORKDIR" EXIT

PRINTER=$(lpstat -d 2>/dev/null | awk -F': ' '{print $2}')

if [ -z "$PRINTER" ]; then
    PRINTER=$(lpstat -p | awk '{print $2}' | \
        zenity --list \
               --title="Select Printer" \
               --column="Printers" \
               --height=300 --width=300)
fi

if [ -z "$PRINTER" ]; then
    zenity --error --text="No printer selected."
    exit 1
fi

MODE=$(zenity --list --radiolist \
    --title="Print Mode" \
    --column="" --column="Mode" \
    TRUE "Color" \
    FALSE "Black and White" \
    --height=200 --width=300)

if [ "$MODE" = "Black and White" ]; then
    PRINTER_OPTIONS="-o print-color-mode=monochrome"
else
    PRINTER_OPTIONS="-o print-color-mode=color"
fi

TOTAL_PAGES=$(pdfinfo "$INPUT" | awk '/Pages/ {print $2}')
PADDED="$WORKDIR/padded.pdf"

if (( TOTAL_PAGES % 2 == 1 )); then
    echo "" | ps2pdf - "$WORKDIR/blank.pdf"
    pdftk "$INPUT" "$WORKDIR/blank.pdf" cat output "$PADDED"
    TOTAL_PAGES=$((TOTAL_PAGES + 1))
else
    cp "$INPUT" "$PADDED"
fi

ODD_PAGES=$(seq 1 2 $TOTAL_PAGES)
EVEN_PAGES=$(seq 2 2 $TOTAL_PAGES)

ODD_REVERSED=$(printf "%s\n" $ODD_PAGES | sort -nr | tr '\n' ' ')
EVEN_FLAT=$(printf "%s " $EVEN_PAGES)

ODD_PDF="$WORKDIR/odd.pdf"
EVEN_PDF="$WORKDIR/even.pdf"

pdftk "$PADDED" cat $ODD_REVERSED output "$ODD_PDF"
pdftk "$PADDED" cat $EVEN_FLAT output "$EVEN_PDF"

lp -d "$PRINTER" $PRINTER_OPTIONS "$ODD_PDF"

zenity --info \
    --title="Manual Duplex Required" \
    --text="Flip the printed pages, reload them into the printer, then click OK to continue."

lp -d "$PRINTER" $PRINTER_OPTIONS "$EVEN_PDF"

zenity --info \
    --title="Printing Complete" \
    --text="Your document has been sent to the printer."
