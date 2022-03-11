#! /usr/bin/env python3
# -*- coding: UTF-8 -*-
# CLI tester for RFX synth
# used during synth development
# $ python -i testrfx.py

import RFX
import wx
import wx.adv
import sys
from collections import deque
App=wx.App()
s=wx.adv.Sound()
stack=deque(maxlen=5)
def p():
    """Plays the sound at the top of the stack, or nothing if stack is empty."""
    try:
        s.CreateFromData(stack[-1].Create())
        s.Play()
    except IndexError:
        pass
def r():
    """Adds a randomized sound to the stack."""
    stack.append(RFX.SFXRWave.randomize())
    p()
def m():
    """Adds a mutation of the last item to the stack."""
    try:
        stack.append(stack[-1].mutate())
        p()
    except IndexError:
        print("Nothing to mutate.")
def undo():
    """Undoes the last operation, returns to previous item on stack."""
    try:
        stack.pop()
        p()
    except IndexError:
        print("Nothing to undo.")
def l(s):
    """Loads a sound from the string given as the single argument."""
    try:
        g=RFX.SFXRWave()
        g.load(s)
        stack.append(g)
        p()
    except ValueError:
        print("Bad data")
def w(name):
    """Writes the current item to a wave file given by the single parameter.
    Parameter must not have extension."""
    try:
        f=open(name+'.wav','wb')
        f.write(stack[-1].Create())
        f.close()
    except IndexError:
        print("Nothing to write")
def g():
    """Just gets the last item on the stack and returns it. Useful for changing synth params."""
    return stack[-1]
