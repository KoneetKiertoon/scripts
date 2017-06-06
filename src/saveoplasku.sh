#!/bin/bash 
#
# Use saveOPlasku.rec to then rename lasku.pdf to $1_$2.pdf
# 
# usage: saveoplasku <CompanyBillIsFrom> <DatePaymentWasMade>
#
if (( $# != 2 )); then
	echo "Usage: saveoplasku <CompanyBillIsFrom> <DatePaymentWasMade>"
else
    rm lasku.pdf #if there happens to be one for some reason it causes an extra dialog in printing
    xmacroplay "$DISPLAY" < saveOPlasku.rec
    mv lasku.pdf $1_$2.pdf
fi
