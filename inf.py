#! /usr/bin/env python3.7
import RFX
g=RFX.SFXRWave()
g.load('AQAAAM3MTL0AAAAAAAAAABSuxz4K1yO+zcwMP/Yo3D4fhWs+KVyPPQAAgD6PwnU+AAAAAI/C9TwAAEC/mplZP8P1KL/NzEw9j8J1Pj0K1757FC4+zczMPs3MTL3Xo3A/DwA=')
f=open('inf.wav','wb')
f.write(g.Create())
f.close()
