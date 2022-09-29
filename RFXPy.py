#! /usr/bin/env python3
# -*- Coding: UTF-8 -*-

import queue
import threading
import time
from collections import deque, namedtuple

import wx
import wx.adv
from pubsub import pub

import RFX

synthcall=queue.Queue()
synthstate=namedtuple('synthstate', ['wave_type', 'base_freq', 'freq_limit', 'freq_ramp', 'freq_dramp',
    'duty', 'duty_ramp', 'vib_strength', 'vib_speed', 'vib_delay',
    'env_attack', 'env_sustain', 'env_decay', 'env_punch',
    'lpf_resonance', 'lpf_freq', 'lpf_ramp', 'hpf_freq', 'hpf_ramp',
    'pha_offset', 'pha_ramp', 'repeat_speed', 'arp_speed', 'arp_mod',
    'SuperSample', 'Sample_Rate'])
synthvalues=None

class SynthThread(threading.Thread):
    def __init__(self, *args, **kwargs):
        super().__init__(*args,**kwargs)
        self._stack=deque(maxlen=5)
        self._undostack=deque(maxlen=5)
        self.sound=wx.adv.Sound()
        self._regen=True
    
    def update(self):
        global synthvalues
        g=self._stack[-1]
        synthvalues=synthstate(g.wave_type, g.p_base_freq, g.p_freq_limit, g.p_freq_ramp, g.p_freq_dramp,
            g.p_duty, g.p_duty_ramp, g.p_vib_strength, g.p_vib_speed, g.p_vib_delay,
            g.p_env_attack, g.p_env_sustain, g.p_env_decay, g.p_env_punch,
            g.p_lpf_resonance, g.p_lpf_freq, g.p_lpf_ramp, g.p_hpf_freq, g.p_hpf_ramp,
            g.p_pha_offset, g.p_pha_ramp, g.p_repeat_speed, g.p_arp_speed, g.p_arp_mod,
            g.SuperSample, g.Sample_Rate)
        pub.sendMessage('updatestate',s=synthvalues)
        self._regen=True
    
    def play(self):
        try:
            if self._regen:
                self.sound.CreateFromData(self._stack[-1].Create())
                self._regen=False
            self.sound.Play()
        except IndexError: pass
    
    def randomize(self):
        g=RFX.SFXRWave.randomize()
        self._stack.append(g)
        self.update()
        self.play()
    
    def mutate(self):
        try:
            self._stack.append(self._stack[-1].mutate())
            self.update()
            self.play()
        except IndexError: pass
    
    def undo(self):
        if len(self._stack) <2: return
        self._undostack.append(self._stack.pop())
        self.update()
        self.play()
    
    def redo(self):
        if len(self._undostack)<1: return
        self._stack.append(self._undostack.pop())
        self.update()
        self.play()
    
    def load(self, encdata):
        try:
            g=RFX.SFXRWave()
            g.load(encdata)
            self._stack.append(g)
            self.update()
            self.play()
        except RFX.InvalidDataError:
            pub.sendMessage('error','Invalid encoded data.')
        except RFX.NewerDataError:
            pub.sendMessage('error','This data was made with a newer version of this application.')
    
    def save(self, filename):
        try:
            pub.sendMessage('save',name=filename,data=self._stack[-1].save())
        except IndexError:
            pub.sendMessage('error','Nothing to save.')
    
    def change(self, *args, **kwargs):
        try:
            g=self._stack[-1]
        except IndexError:
            g=RFX.SFXRWave()
            self._stack.append(g)
        finally:
            if len(args)==len(synthvalues):
                (g.wave_type, g.p_base_freq, g.p_freq_limit, g.p_freq_ramp, g.p_freq_dramp,
                g.p_duty, g.p_duty_ramp, g.p_vib_strength, g.p_vib_speed, g.p_vib_delay,
                g.p_env_attack, g.p_env_sustain, g.p_env_decay, g.p_env_punch,
                g.p_lpf_resonance, g.p_lpf_freq, g.p_lpf_ramp, g.p_hpf_freq, g.p_hpf_ramp,
                g.p_pha_offset, g.p_pha_ramp, g.p_repeat_speed, g.p_arp_speed, g.p_arp_mod,
                g.SuperSample, g.Sample_Rate)=args    
            if len(kwargs)>0:
                for k, v in kwargs.items():
                    setattr(g,k,v)
            self.update()
            self.play()
    
    def run(self):
        while True:
            v=synthcall.get()
            if v is None:
                synthcall.task_done()
                self._stack.clear()
                self._undostack.clear()
                synthvalues=None
                return
            if isinstance(v,tuple):
                func=v[0]
                if len(v)==2:
                    if isinstance(v[1],dict):
                        kwargs=v[1]
                        args=[]
                    elif isinstance(v[1],tuple):
                        args=v[1]
                        kwargs={}
                elif len(v)==3:
                    args, kwargs=v[1:]
            elif isinstance(v,str):
                func=v
                args=[]
                kwargs={}
            f=getattr(self,func,None)
            if callable(f): f(*args,**kwargs)
            synthcall.task_done()

App=wx.App()
st=SynthThread()
synthcall.put('randomize')
st.start()

class FloatSlider(wx.Slider): 
    def __init__(self, parent, sizer, attribute): 
        super().__init__(parent, value = 50)
        self.label = wx.TextCtrl(parent, label = attribute)
        sizer.add(self.label)
        sizer.add(self)
        self.attribute = attribute
        self.Bind(wx.EVT_SLIDER, self.on_scroll)
    def on_scroll(self, e): 
        value = self.getValue()/50-1.0
        synthcall.put(("change", {self.attribute: value}))

class MainWindow(wx.Frame): 
    def __init__(self): 
        wx.Frame.__init__(self, None, title = "Retroar FX Generator")
        p = wx.Panel(self)
        box = wx.BoxSizer()
        master= wx.StaticBoxSizer(wx.HORIZONTAL, p, label = "Master Controls")
        box.Add(master)
        self.masterbox= master.GetStaticBox()
        self.randombtn = wx.Button(self.masterbox, label = "&Random")
        master.Add(self.randombtn)
        self.randombtn.Bind(wx.EVT_BUTTON, self.on_random)
        self.playbtn = wx.Button(self.masterbox, label = "&Play")
        master.add(self.playbtn)
        self.playbtn.Bind(wx.EVT_BUTTON, self.on_play)
        self.mutatebtn = wx.Button(self.masterbox, label = "&Mute")
        master.Add(self.mutatebtn)
        self.mutatebtn.Bind(wx.EVT_BUTTON, self.on_mutate)
        imp = wx.StaticBoxSizer(wx.HORIZONTAL, p, label = "Import/Export")
        box.Add(imp)
        self.impbox = imp.GetStaticBox()
        self.loadbtn = wx.Button(self.impbox, label = "&Load")
        imp.Add(self.loadbtn)
        self.loadbtn.Bind(wx.EVT_BUTTON, self.on_load)
        self.savebtn = wx.Button(self.impbox, label = "&Save")
        imp.Add(self.loadbtn)
        self.loadbtn.Bind(wx.EVT_BUTTON, self.on_save)
        self.savewavbtn = wx.Button(self.impbox, label = "Save &Wav")
        imp.Add(self.savewavbtn)
        self.savewavbtn.Bind(wx.EVT_BUTTON, self.on_savewav)
        self.loadclipbtn = wx.Button(self.impbox, label = "L&oad from Clipboard")
        imp.Add(self.loadclipbtn)
        self.loadclipbtn.Bind(wx.EVT_BUTTON, self.on_loadclip)
        self.saveclipbtn = wx.Button(self.impbox, label = "Save to &Clipboard")
        imp.Add(self.saveclipbtn)
        self.saveclipbtn.Bind(wx.EVT_BUTTON, self.on_saveclip)
        presets_lable = wx.StaticText(p, label = "Presets")
        box.Add(presets_lable)
        self.presets = wx.Choice(p, choices = [
            "Coin", 
            "Laser", 
            "Explosion", 
            "Powerup", 
            "Hit", 
            "Jump", 
            "Blip", 
        ])
        box.Add(self.presets)
        self.presets.Bind(wx.EVT_CHOICE, self.on_preset)
        wavetype_label = wx.StaticText(p, label = "Wave Type")
        box.Add(wavetype_label)
        self.wavetype = wx.Choice(p, choices = [
            "Square", 
            "Saw", 
            "Sine", 
            "white noise", 
            "pink noise", 
            "brown noise", 
            "triangle", 
            "breaker", 
            "absolute sine", 
        ])
        self.wavetype.Bind(wx.EVT_CHOICE, self.on_wavetype)
        
frame = MainWindow()
frame.show()
App.MainLoop()
