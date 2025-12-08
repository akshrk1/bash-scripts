#!/usr/bin/env bash

if [ -z "$1" ]; then
    echo "Usage: $0 input.pdf"
    exit 1
fi

INPUT="$1"

WORKDIR=$(mktemp -d)
trap "rm -rf $WORKDIR" EXIT

PRINTER=$(lpstat -d 2>/dev/null | awk -F': ' '{print $2}')

if [ -z "$PRINTER" ]; then
    echo "No default printer detected."
    echo "Available printers:"
    lpstat -p | awk '{print $2}'

    echo -n "Enter printer name: "
    read -r PRINTER
fi

echo "Using printer: $PRINTER"

TOTAL_PAGES=$(pdfinfo "$INPUT" | awk '/Pages/ {print $2}')
echo "Total pages: $TOTAL_PAGES"

PADDED="$WORKDIR/padded.pdf"

if (( TOTAL_PAGES % 2 == 1 )); then
    echo "Adding blank page..."
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

echo "Odd pages (reversed): $ODD_REVERSED"
echo "Even pages: $EVEN_FLAT"

ODD_PDF="$WORKDIR/odd.pdf"
EVEN_PDF="$WORKDIR/even.pdf"

pdftk "$PADDED" cat $ODD_REVERSED output "$ODD_PDF"
pdftk "$PADDED" cat $EVEN_FLAT output "$EVEN_PDF"

echo "Printing odd pages..."
lp -d "$PRINTER" "$ODD_PDF"

echo
echo ">>> Flip the pages and load them back into the printer"
read -p "Press ENTER to continue..."

echo "Printing even pages..."
lp -d "$PRINTER" "$EVEN_PDF"

echo "Done!"
