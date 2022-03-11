#! /usr/bin/env python3
# -*- Coding: UTF-8 -*-
# infinity test case
# The port seems to differ from the original code here
# the original code will madly clip this string
# while this code seems to ignore the infinity and just produces a normal wave
# unsure of which behavior is desireable at this time
# or how to get this to behave like the original
# that version of PureBasic appears to ignore division by 0 and give inf
# but sign is undetermined, I don't have that version to test with
import RFX
g=RFX.SFXRWave()
g.load('AQAAAM3MTL0AAAAAAAAAABSuxz4K1yO+zcwMP/Yo3D4fhWs+KVyPPQAAgD6PwnU+AAAAAI/C9TwAAEC/mplZP8P1KL/NzEw9j8J1Pj0K1757FC4+zczMPs3MTL3Xo3A/DwA=')
f=open('inf.wav','wb')
f.write(g.Create())
f.close()
