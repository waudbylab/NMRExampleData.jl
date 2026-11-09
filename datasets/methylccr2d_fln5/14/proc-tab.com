#!/bin/csh

autoFit.tcl -specName ft/test%03d.ft2 -inTab test.tab -series
awk 'BEGIN {ORS=""; print "resi={\""} (NR>18) {print $23 "\", \""} END {print "\"}\n"}' nlin.tab
awk '(NR>18){print $23, $18, $19, $26, $27, $28, $29, $30, $31, $32, $33}' nlin.tab | sort -n
