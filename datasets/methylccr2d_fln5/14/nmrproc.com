#!/bin/csh

bruk2pipe -in ./ser \
  -bad 0.0 -ext -aswap -AMX -decim 2000 -dspfvs 21 -grpdly 76  \
  -xN              2048  -yN                 8  -zN                80  \
  -xT              1024  -yT                 8  -zT                40  \
  -xMODE            DQD  -yMODE           Real  -zMODE    States-TPPI  \
  -xSW        10000.000  -ySW            8.000  -zSW         1194.743  \
  -xOBS         500.180  -yOBS           1.000  -zOBS         125.773  \
  -xCAR           0.700  -yCAR           0.000  -zCAR          20.250  \
  -xLAB              1H  -yLAB             TAU  -zLAB             13C  \
  -ndim               3  -aq2D         Complex                         \
| nmrPipe -fn TP  | nmrPipe -fn ZTP  | nmrPipe -fn TP -hyper \
| pipe2xyz -out ./fid/test%03d.fid -verb -ov

xyz2pipe -in fid/test%03d.fid -x -verb              \
#| nmrPipe  -fn SOL                                  \
#| nmrPipe  -fn GM -g1 8.0 -g2 12.0 -g3 0.0 -c 1.0   \
| nmrPipe -fn SP  -off 0.4 -end 0.98 -pow 2 -c 1.0             \
| nmrPipe  -fn ZF -auto                             \
| nmrPipe  -fn FT                                   \
| nmrPipe  -fn PS -p0 47 -p1 0.0 -di               \
| nmrPipe  -fn EXT -xn 1.5ppm -x1 -1.5ppm -sw           \
| nmrPipe  -fn TP                                   \
| nmrPipe  -fn LP -fb                               \
| nmrPipe -fn SP  -off 0.4 -end 0.98 -pow 2 -c 1.0             \
#| nmrPipe  -fn GM -g1 4.0 -g2 15.0 -g3 0.0 -c 0.5   \
| nmrPipe  -fn ZF -auto                             \
| nmrPipe  -fn FT -alt -neg                                  \
| nmrPipe  -fn PS -p0 -90.0 -p1 180.0 -di               \
| pipe2xyz -out ft/test%03d.ft2 -y

#cp ft/test001.ft2 first-plane.ft2
#sethdr first-plane.ft2 -ndim 2 -zN 1 -zT 1
#pipe2ucsf first-plane.ft2 first-plane.ucsf

