#! /usr/bin/env python3
# -*- coding: UTF-8 -*-
import RFX
import wx
import wx.adv
import sys
from collections import deque
App=wx.App()
s=wx.adv.Sound()
stack=deque()
def p():
    try:
        s.CreateFromData(stack[-1].Create())
        s.Play()
    except IndexError:
        pass
def r():
    stack.append(RFX.SFXRWave.randomize())
    p()
def m():
    try:
        stack.append(stack[-1].mutate())
        p()
    except IndexError:
        print("Nothing to mutate.")
def undo():
    try:
        stack.pop()
        p()
    except IndexError:
        print("Nothing to undo.")
def l(s):
    g=RFX.SFXRWave()
    g.load(s)
    stack.append(g)
    p()
def w(name):
    try:
        f=open(name+'.wav','wb')
        f.write(stack[-1].Create())
        f.close()
    except IndexError:
        print("Nothing to write")
