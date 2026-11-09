#!/bin/csh

bruk2pipe -in ./ser \
  -bad 0.0 -ext -aswap -AMX -decim 1904 -dspfvs 21 -grpdly 76  \
  -xN              2048  -yN               256  -zN                64  \
  -xT              1024  -yT               128  -zT                32  \
  -xMODE            DQD  -yMODE    States-TPPI  -zMODE    States-TPPI  \
  -xSW        10504.202  -ySW         4226.543  -zSW         1561.037  \
  -xOBS         700.133  -yOBS         176.057  -zOBS          70.952  \
  -xCAR           4.773  -yCAR          56.737  -zCAR         118.581  \
  -xLAB              HN  -yLAB             13C  -zLAB             15N  \
  -ndim               3  -aq2D         Complex                         \
  -out ./fid/test%03d.fid -verb -ov
