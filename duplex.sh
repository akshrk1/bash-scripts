#!/usr/bin/env bash

# --- Configuration Function ---

# Function to determine printing mode (color or grayscale)
get_color_mode() {
    local CHOICE
    # Default to 'color' if not specified or if user input is invalid
    PRINTER_OPTIONS=""

    echo "--- Print Mode Selection ---"
    echo "1. Color (Default)"
    echo "2. Black and White (Grayscale)"
    echo -n "Enter your choice (1 or 2): "
    read -r CHOICE

    case "$CHOICE" in
        2)
            # Use 'print-color-mode=monochrome' for black and white
            PRINTER_OPTIONS="-o print-color-mode=monochrome"
            echo "Selected mode: Black and White"
            ;;
        1|*)
            # Use 'print-color-mode=color' or no option for color (often default)
            # Explicitly set to 'color' for clarity, though it's often the default.
            PRINTER_OPTIONS="-o print-color-mode=color"
            echo "Selected mode: Color"
            ;;
    esac
}

# --- Main Script Logic ---

if [ -z "$1" ]; then
    echo "Usage: $0 input.pdf"
    exit 1
fi

INPUT="$1"

# Create a temporary directory for intermediary files, and ensure cleanup on exit
WORKDIR=$(mktemp -d)
trap "rm -rf $WORKDIR" EXIT

# 1. Find the default printer
PRINTER=$(lpstat -d 2>/dev/null | awk -F': ' '{print $2}')

if [ -z "$PRINTER" ]; then
    echo "No default printer detected."
    echo "Available printers:"
    lpstat -p | awk '{print $2}'

    echo -n "Enter printer name: "
    read -r PRINTER
fi

# Exit if printer name is still empty after user input
if [ -z "$PRINTER" ]; then
    echo "Error: No printer name provided. Exiting."
    exit 1
fi

echo "Using printer: $PRINTER"

# 2. Get the color mode selection
get_color_mode # This call populates the PRINTER_OPTIONS variable

# 3. Handle page padding for odd-numbered documents
TOTAL_PAGES=$(pdfinfo "$INPUT" | awk '/Pages/ {print $2}')
echo "Total pages: $TOTAL_PAGES"

PADDED="$WORKDIR/padded.pdf"

if (( TOTAL_PAGES % 2 == 1 )); then
    echo "Adding blank page to make total pages even..."
    # Create a blank PDF using ps2pdf (PostScript -> PDF)
    echo "" | ps2pdf - "$WORKDIR/blank.pdf"
    # Concatenate original PDF and the blank page
    pdftk "$INPUT" "$WORKDIR/blank.pdf" cat output "$PADDED"
    TOTAL_PAGES=$((TOTAL_PAGES + 1))
else
    cp "$INPUT" "$PADDED"
fi

# 4. Determine page sequences for manual duplex
# Odd pages: 1, 3, 5, ...
ODD_PAGES=$(seq 1 2 $TOTAL_PAGES)
# Even pages: 2, 4, 6, ...
EVEN_PAGES=$(seq 2 2 $TOTAL_PAGES)

# Front side (Odd pages) must be printed in reverse order (e.g., 9, 7, 5, 3, 1)
# so that when the stack is flipped, page 1 is on top.
ODD_REVERSED=$(printf "%s\n" $ODD_PAGES | sort -nr | tr '\n' ' ')
# Back side (Even pages) are printed in sequential order (e.g., 2, 4, 6, 8, 10)
EVEN_FLAT=$(printf "%s " $EVEN_PAGES)

echo "Odd pages (reversed): $ODD_REVERSED"
echo "Even pages: $EVEN_FLAT"

# 5. Split the PDF into two jobs
ODD_PDF="$WORKDIR/odd.pdf"
EVEN_PDF="$WORKDIR/even.pdf"

# Extract reversed odd pages (front side)
pdftk "$PADDED" cat $ODD_REVERSED output "$ODD_PDF"
# Extract flat even pages (back side)
pdftk "$PADDED" cat $EVEN_FLAT output "$EVEN_PDF"

# 6. Print the first side (Odd pages)
echo "Printing odd pages (First Pass)..."
# The '-o' option is added here to specify color mode
lp -d "$PRINTER" $PRINTER_OPTIONS "$ODD_PDF"

echo
echo ">>> **MANUAL STEP REQUIRED:** Flip the printed pages and load them back into the printer."
read -r -p "Press ENTER to continue with the second pass..."

# 7. Print the second side (Even pages)
echo "Printing even pages (Second Pass)..."
# The '-o' option is added here to specify color mode
lp -d "$PRINTER" $PRINTER_OPTIONS "$EVEN_PDF"

echo "Done! Final document printed to $PRINTER."
