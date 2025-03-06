movri  r0, 0
movri  r1, 1
movri  r3, 0
addrrr r2, r0, r1
movrr  r0, r1
movrr  r1, r2
addrri r3, r3, 1
cmpri  r4, r3, 10
jleri  r4, 3


dbgprintr r4