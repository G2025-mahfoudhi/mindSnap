#!/bin/bash
# Tessdata installé par le buildpack apt — tesseract 5.x
export TESSDATA_PREFIX="/app/.apt/usr/share/tesseract-ocr/5/tessdata"

# Autoriser ImageMagick à lire les PDF (policy restrictive par défaut)
POLICY_FILE="/app/.apt/etc/ImageMagick-6/policy.xml"
if [ -f "$POLICY_FILE" ]; then
  sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' "$POLICY_FILE"
fi
