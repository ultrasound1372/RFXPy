;Retroar FX Generator
; Based on the SpotFX Test App by PJay
;Requires PB 4.61

XIncludeFile("Spotfx2b Include.pbi")
;EnableExplicit

Declare SettabsTop(gadget.l)
Declare SaveWav()
Declare.s savereq(title.s,msg.s,ext.s)
Declare ProcessGUI(event.l)

Structure DSBCAPS 
  dwSize.l 
  dwFlags.l 
  dwBufferBytes.l 
  dwUnlockTransferRate.l 
  dwPlayCpuOverhead.l 
EndStructure 


Enumeration
  #Control_Frame
  #Import_Frame
  #Presets_Frame
  #Random
  #Play
  #Coin
  #Laser
  #Explosion
  #PowerUp
  #Hit
  #Jump
  #Blip
  #Mutate
  #Spare
    #Load_sfs
  #Load_Seed
  #Load_B64
  #LoadfromClipboard
  #SaveToClipboard
  
  #SuperSamples
  #Supersamples_Txt
  
  #Combobox_WaveType
  #Combobox_WaveType_Txt
  
  #Attack
  #Decay
  #Sustain
  #punch
  #Base_Freq
  #Freq_Limit
  #Ramp
  #D_Ramp
  #Vibrato_Strength
  #Vibrato_Speed
  #Vibrato_Delay
  #Arp_Amount
  #Arp_Speed
  #Square_Duty
  #Duty_Sweep
  #Repeat_Speed
  #Phase_Offset
  #Phase_Ramp
  #LPF_Resonance
  #LPF_Freq
  #LPF_Ramp
  #HPF_Freq
  #HPF_Ramp
  #Attack_Txt
  #Decay_Txt
  #Sustain_Txt
  #punch_Txt
  #Base_Freq_Txt
  #Freq_Limit_Txt
  #Ramp_Txt
  #D_Ramp_Txt
  #Vibrato_Strength_Txt
  #Vibrato_Speed_Txt
  #Vibrato_Delay_Txt
  #Arp_Amount_Txt
  #Arp_Speed_Txt
  #Square_Duty_Txt
  #Duty_Sweep_Txt
  #Repeat_Speed_Txt
  #Phase_Offset_Txt
  #Phase_Ramp_Txt
  #LPF_Resonance_Txt
  #LPF_Freq_Txt
  #LPF_Ramp_Txt
  #HPF_Freq_Txt
  #HPF_Ramp_Txt
EndEnumeration
Global EventID.i, MySeed.i, Update.i = 1, B64String.s = ""

 
Procedure IsSoundPlaying(Sound);returns whether the Sound is playing or not. 
  Protected Address.i, Status.i, *DSB.IDirectSoundBuffer
  Address=IsSound(Sound) 
  If Address=0:ProcedureReturn 0 :EndIf 
  *DSB = PeekL(Address) 
  *DSB\GetStatus(@Status) 
  If Status=1 Or Status=5 
    ProcedureReturn 1 
  EndIf 
  ProcedureReturn 0 
EndProcedure 
Procedure GetSoundPositionB(Sound);returns the current position of the Sound.(in bytes) 
  Protected Address.i, *DSB.IDirectSoundBuffer, Position.i
  Address=IsSound(Sound) 
  If Address=0:ProcedureReturn 0:EndIf 
  *DSB=PeekL(Address) 
  *DSB\GetCurrentPosition(@Position,0) 
  ProcedureReturn Position 
EndProcedure 
Procedure GetSoundSize(Sound);Returns the size of the Sound in bytes. 
  Protected Address.i, *DSB.IDirectSoundBuffer, Caps.DSBCAPS
  Address=IsSound(Sound) 
  If Address=0:ProcedureReturn 0:EndIf 
  *DSB.IDirectSoundBuffer=PeekL(Address) 
  Caps\dwSize=SizeOf(DSBCAPS) 
  *DSB\GetCaps(@Caps) 
  ProcedureReturn Caps\dwBufferBytes 
EndProcedure 
Procedure.s Base64Enc()
  Protected *mem, *mem2, enc.s, *pkmem
  *mem=AllocateMemory(1024)
  enc.s=Space(1024)
  
  CopyMemory(@SFX_Wave,*mem,SizeOf(GenBits))
  Base64EncoderBuffer(*mem, SizeOf(GenBits), @enc, 1024)
  FreeMemory(*mem)
  ProcedureReturn PeekS(@enc,StringByteLength(enc),#PB_Ascii)
EndProcedure
Procedure ResetParams()
  With SFX_Wave
    \SuperSample = 8
    \wave_type=0;
    
    \p_base_freq=0.3
    \p_freq_limit=0.0
    \p_freq_ramp=0.0
    \p_freq_dramp=0.0
    \p_duty=0.0
    \p_duty_ramp=0.0
    
    \p_vib_strength=0.0
    \p_vib_speed=0.0
    \p_vib_delay=0.0
    
    \p_env_attack=0.0
    \p_env_sustain=0.3
    \p_env_decay=0.4
    \p_env_punch=0.0
    
    \filter_on=#False;
    \p_lpf_resonance=0.0
    \p_lpf_freq=1.0
    \p_lpf_ramp=0.0
    \p_hpf_freq=0.0
    \p_hpf_ramp=0.0
    
    \p_pha_offset=0.0
    \p_pha_ramp=0.0
    
    \p_repeat_speed=0.0
    
    \p_arp_speed=0.0
    \p_arp_mod=0.0
  EndWith
EndProcedure
Procedure GetValues()
  With SFX_Wave
    \wave_type = GetGadgetState(#Combobox_WaveType)
    \sample_rate=0
    \SuperSample = GetGadgetState(#SuperSamples)
    \p_env_attack  = GetGadgetState(#Attack)/100.0
    \p_env_sustain = GetGadgetState(#Sustain)/100.0
    \p_env_decay   = GetGadgetState(#Decay)/100.0
    \p_env_punch   = GetGadgetState(#punch)/100.0
    \p_base_freq   = GetGadgetState(#Base_Freq)/100.0
    \p_freq_limit  = GetGadgetState(#Freq_Limit)/100.0
    \p_freq_ramp   = GetGadgetState(#Ramp)/100.0
    \p_freq_dramp  = GetGadgetState(#D_Ramp)/100.0
    \p_vib_strength= GetGadgetState(#Vibrato_Strength)/100.0
    \p_vib_speed   = GetGadgetState(#Vibrato_Speed)/100.0
    \p_vib_delay   = GetGadgetState(#Vibrato_Delay)/100.0
    \p_arp_mod    = GetGadgetState(#Arp_Amount)/100.0
    \p_arp_speed  = GetGadgetState(#Arp_Speed)/100.0
    \p_duty       = GetGadgetState(#Square_Duty)/100.0
    \p_duty_ramp  = GetGadgetState(#Duty_Sweep)/100.0
    \p_pha_offset = GetGadgetState(#Phase_Offset)/100.0
    \p_pha_ramp   = GetGadgetState(#Phase_Ramp)/100.0
    \p_repeat_speed = GetGadgetState(#Repeat_Speed)/100.0
    \p_lpf_resonance = GetGadgetState(#LPF_Resonance)/100.0
    \p_lpf_freq = GetGadgetState(#LPF_Freq)/100.0
    \p_lpf_ramp = GetGadgetState(#LPF_Ramp)/100.0
    \p_hpf_freq = GetGadgetState(#HPF_Freq)/100.0
    \p_hpf_ramp = GetGadgetState(#HPF_Ramp)/100.0
    EndWith
  
EndProcedure
Procedure SetValues()
  With SFX_Wave
        SetGadgetState(#SuperSamples,\SuperSample)
    SetGadgetState(#Combobox_WaveType,\wave_type)
    SetGadgetState(#Attack,\p_env_attack*100)
    SetGadgetState(#Sustain,\p_env_sustain*100)
    SetGadgetState(#Decay,\p_env_decay*100)
    SetGadgetState(#punch,(\p_env_punch*100))
    SetGadgetState(#Base_Freq,\p_base_freq*100)
    SetGadgetState(#Freq_Limit,\p_freq_limit*100)
    SetGadgetState(#Ramp,\p_freq_ramp*100)
    SetGadgetState(#D_Ramp,\p_freq_dramp*100)
    SetGadgetState(#Vibrato_Strength,\p_vib_strength*100)
    SetGadgetState(#Vibrato_Speed,\p_vib_speed*100)
    SetGadgetState(#Vibrato_Delay,\p_vib_delay*100)
    SetGadgetState(#Arp_Amount,\p_arp_mod*100)
    SetGadgetState(#Arp_Speed,\p_arp_speed*100)
    SetGadgetState(#Square_Duty,\p_duty*100)
    SetGadgetState(#Duty_Sweep,\p_duty_ramp*100)
    SetGadgetState(#Repeat_Speed,\p_repeat_speed*100.0)
    SetGadgetState(#Phase_Offset,\p_pha_offset*100)
    SetGadgetState(#Phase_Ramp,\p_pha_ramp*100)
SetGadgetState(#LPF_Resonance,\p_lpf_resonance*100)
    SetGadgetState(#LPF_Freq,\p_lpf_freq*100)
    SetGadgetState(#LPF_Ramp,\p_lpf_ramp*100)
    SetGadgetState(#HPF_Freq,\p_hpf_freq*100)
    SetGadgetState(#HPF_Ramp,\p_hpf_ramp*100)
  EndWith
    ;GetValues()
    EndProcedure
Procedure LoadSFS()
    Protected Pattern$, file$;, sound_vol.i, Version.i
  Pattern$ = "Dragonflame Sound FX (*.dsx)|*.dsx"
  file$ = OpenFileRequester("Please choose file to load", "", Pattern$, 0)
  If file$=""
    ProcedureReturn
  EndIf
      If GetExtensionPart(file$)<>"dsx":file$+".dsx":EndIf
  If file$ = "" Or FileSize(file$)=-1: ProcedureReturn #False : EndIf
  ResetParams()
  OpenFile(1,file$)
  B64String=ReadString(1)
  SpotFX_Decode(B64String)
  SetValues()
  CloseFile(1)
  ProcedureReturn 1
EndProcedure

Procedure SaveSFS(file.s)
  If file="":ProcedureReturn:EndIf
    If GetExtensionPart(file)<>"dsx":file+".dsx":EndIf
  OpenFile(1,file)
  WriteString(1,B64String)
  CloseFile(1)
EndProcedure

Procedure Mutate()
  With SFX_Wave
    If Random(1)=1 : \p_base_freq+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_freq_ramp+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_freq_dramp+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_duty+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_duty_ramp+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_vib_strength+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_vib_speed+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_vib_delay+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_env_attack+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_env_sustain+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_env_decay+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_env_punch+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_lpf_resonance+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_lpf_freq+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_lpf_ramp+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_hpf_freq+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_hpf_ramp+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_pha_offset+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_pha_ramp+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_repeat_speed+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_arp_speed+SpotFX_Rnd(0.1)-0.05 : EndIf
    If Random(1)=1 : \p_arp_mod+SpotFX_Rnd(0.1)-0.05 : EndIf
  EndWith
EndProcedure
Procedure Randomize(seed.i=0)
    If seed = 0
    MySeed = ElapsedMilliseconds()
    RandomSeed(MySeed)
  Else
    RandomSeed(seed)
  EndIf
  
  With SFX_Wave
    \wave_type = Random(3)
    \p_base_freq=Pow(SpotFX_Rnd(2.0)-1.0, 2.0);
    If Random(1)
      \p_base_freq=Pow(SpotFX_Rnd(2.0)-1.0, 3.0)+0.5
    EndIf
    \p_freq_limit=0
    \p_freq_ramp=Pow(SpotFX_Rnd(2.0)-1.0, 5.0);
    If \p_base_freq>0.7 And \p_freq_ramp>0.2
      \p_freq_ramp=-\p_freq_ramp;
    EndIf
    If \p_base_freq<0.2 And \p_freq_ramp<-0.05
      \p_freq_ramp=-\p_freq_ramp;
    EndIf
    \p_freq_dramp=Pow(SpotFX_Rnd(2.0)-1.0, 3);
    \p_duty=SpotFX_Rnd(2.0)-1.0
    \p_duty_ramp=Pow(SpotFX_Rnd(2.0)-1.0, 3);
    \p_vib_strength=Pow(SpotFX_Rnd(2.0)-1.0, 3);
    \p_vib_speed=SpotFX_Rnd(2.0)-1.0
    \p_vib_delay=SpotFX_Rnd(2.0)-1.0
    \p_env_attack=Pow(SpotFX_Rnd(2.0)-1.0, 3);
    \p_env_sustain=Pow(SpotFX_Rnd(2.0)-1.0, 2.0);
    \p_env_decay=SpotFX_Rnd(2.0)-1.0
    \p_env_punch=Pow(SpotFX_Rnd(0.8), 2.0);
    If \p_env_attack+\p_env_sustain+\p_env_decay<0.2
      \p_env_sustain+ (0.2+SpotFX_Rnd(0.3));
      \p_env_decay+ (0.2+SpotFX_Rnd(0.3));
    EndIf
    \p_lpf_resonance=SpotFX_Rnd(2.0)-1.0
    \p_lpf_freq=1.0-Pow(SpotFX_Rnd(1.0), 3.0);
    \p_lpf_ramp=Pow(SpotFX_Rnd(2.0)-1.0, 3.0);
    If \p_lpf_freq<0.1 And \p_lpf_ramp<-0.05 
      \p_lpf_ramp=-\p_lpf_ramp;
    EndIf
    \p_hpf_freq=Pow(SpotFX_Rnd(1.0), 5.0);
    \p_hpf_ramp=Pow(SpotFX_Rnd(2.0)-1.0, 5.0);
    \p_pha_offset=Pow(SpotFX_Rnd(2.0)-1.0, 3.0);
    \p_pha_ramp=Pow(SpotFX_Rnd(2.0)-1.0, 3.0);
    \p_repeat_speed=SpotFX_Rnd(2.0)-1.0
    \p_arp_speed=SpotFX_Rnd(2.0)-1.0
    \p_arp_mod=SpotFX_Rnd(2.0)-1.0
    \SuperSample = Random(14)+2
  EndWith
    SetValues()
EndProcedure

Procedure Init_Gadgets()
  Protected X.i,Y.i,space.i
  X=20
  Frame3DGadget(#Control_Frame,X,2,153,39,"&Master Controls")
  X + 4 : Y = 18: space = 16 
  ButtonGadget(#Random,X,Y,46,18,"&Random") : X + 50
  ButtonGadget(#Play,X,Y,46,18,"&Play") : X + 50
  ButtonGadget(#Mutate,X,Y,46,18,"&Mutate") : X + 96
  
  Frame3DGadget(#Import_Frame,X,2,430,39,"Import/Export") : X+2
  ButtonGadget(#Load_sfs,X,Y,70,18,"&Load") : X + 74; X = 2 ;: Y + 28
  ButtonGadget(#Load_Seed,X,Y,70,18,"&Save") : X + 74; X = 2 ;: Y + 28
  ButtonGadget(#Load_B64,X,Y,70,18,"Save &Wav") : X + 94; X = 2 ;: Y + 28
  ButtonGadget(#LoadfromClipboard,X,Y,70,18,"L&oad from Clipboard") : X + 114; X = 2 ;: Y + 28
  ButtonGadget(#SaveToClipboard,X,Y,70,18,"Save to &Clipboard") : X + 134; X = 2 ;: Y + 28
  
  Frame3DGadget(#Presets_Frame,X,2,354,39,"Presets") : X+2
  ButtonGadget(#Coin,X,Y,48,18,"Coi&n") : X + 50
  ButtonGadget(#Laser,X,Y,48,18,"L&aser") : X + 50
  ButtonGadget(#Explosion,X,Y,48,18,"&Explosion") : X + 50
  ButtonGadget(#PowerUp,X,Y,48,18,"Power&up") : X + 50; X = 2 : Y + 22  
  ButtonGadget(#Hit,X,Y,48,18,"&Hit") : X + 50
  ButtonGadget(#Jump,X,Y,48,18,"&Jump") : X + 50
  ButtonGadget(#Blip,X,Y,48,18,"&Blip") : X + 50
  
  X = 4 : Y + 32
  TextGadget(#Combobox_WaveType_Txt,  X,Y, 80,  20, "Wave &Type:",#PB_Text_Right)
  ComboBoxGadget(#Combobox_WaveType, X+90, Y, 90, 20)
  AddGadgetItem(#Combobox_WaveType, -1, "Square")
  AddGadgetItem(#Combobox_WaveType, -1, "Saw")
  AddGadgetItem(#Combobox_WaveType, -1, "Sine")
  AddGadgetItem(#Combobox_WaveType, -1, "Noise") : SetGadgetState(#Combobox_WaveType,0) : Y+space+8
  
  TextGadget(#Supersamples_Txt,  X,Y, 80,  16, "SuperSample:",#PB_Text_Right)
  TrackBarGadget(#SuperSamples, X+90, Y, 100, 14, 4, 16, 1): Y+space :   
  TextGadget(#Attack_Txt,  X,Y, 80,  16, "Attack:",#PB_Text_Right)
  TrackBarGadget(#Attack, X+90, Y, 100, 14, -100, 100, 1): Y+space :  
  TextGadget(#Decay_Txt,  X,Y, 80,  16, "Decay:",#PB_Text_Right)
  TrackBarGadget(#Decay, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
    TextGadget(#Sustain_Txt,  X,Y, 80,  16, "Sustain:",#PB_Text_Right)
  TrackBarGadget(#Sustain, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#punch_Txt,  X,Y, 80,  16, "Punch:",#PB_Text_Right)
  TrackBarGadget(#punch, X+90, Y, 100, 14, -100, 100, 1): Y+space+5 :   
  TextGadget(#Base_Freq_Txt,  X,Y, 80,  16, "Base Freq:",#PB_Text_Right)
  TrackBarGadget(#Base_Freq, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#Freq_Limit_Txt,  X,Y, 80,  16, "Freq Limit:",#PB_Text_Right)
  TrackBarGadget(#Freq_Limit, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#Ramp_Txt,  X,Y, 80,  16, "Ramp:",#PB_Text_Right)
  TrackBarGadget(#Ramp, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#D_Ramp_Txt,  X,Y, 80,  16, "D_Ramp:",#PB_Text_Right)
  TrackBarGadget(#D_Ramp, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#Vibrato_Strength_Txt,  X,Y, 80,  16, "Vibrato Strength:",#PB_Text_Right)
  TrackBarGadget(#Vibrato_Strength, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#Vibrato_Speed_Txt,  X,Y, 80,  16, "Vibrato Speed:",#PB_Text_Right)
  TrackBarGadget(#Vibrato_Speed, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#Vibrato_Delay_Txt,  X,Y, 80,  16, "Vibrato Delay:",#PB_Text_Right)
  TrackBarGadget(#Vibrato_Delay, X+90, Y, 100, 14, -100, 100, 1): Y+space+5 :   
  TextGadget(#Arp_Amount_Txt,  X,Y, 80,  16, "Arp Amount:",#PB_Text_Right)
  TrackBarGadget(#Arp_Amount, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#Arp_Speed_Txt,  X,Y, 80,  16, "Arp Speed:",#PB_Text_Right)
  TrackBarGadget(#Arp_Speed, X+90, Y, 100, 14, -100, 100, 1): Y+space+5 :   
  TextGadget(#Square_Duty_Txt,  X,Y, 80,  16, "Square Duty:",#PB_Text_Right)
  TrackBarGadget(#Square_Duty, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#Duty_Sweep_Txt,  X,Y, 80,  16, "Duty Sweep:",#PB_Text_Right)
  TrackBarGadget(#Duty_Sweep, X+90, Y, 100, 14, -100, 100, 1): Y+space+5 :   
  TextGadget(#Repeat_Speed_Txt,  X,Y, 80,  16, "Repeat Speed:",#PB_Text_Right)
  TrackBarGadget(#Repeat_Speed, X+90, Y, 100, 14, -100, 100, 1): Y+space+5 :   
  TextGadget(#Phase_Offset_Txt,  X,Y, 80,  16, "Phase Offset:",#PB_Text_Right)
  TrackBarGadget(#Phase_Offset, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#Phase_Ramp_Txt,  X,Y, 80,  16, "Phase Ramp:",#PB_Text_Right)
  TrackBarGadget(#Phase_Ramp, X+90, Y, 100, 14, -100, 100, 1): Y+space+5 :   
  TextGadget(#LPF_Resonance_Txt,  X,Y, 80,  16, "LPF Resonance:",#PB_Text_Right)
  TrackBarGadget(#LPF_Resonance, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#LPF_Freq_Txt,  X,Y, 80,  16, "LPF Freq:",#PB_Text_Right)
  TrackBarGadget(#LPF_Freq, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#LPF_Ramp_Txt,  X,Y, 80,  16, "LPF Ramp:",#PB_Text_Right)
  TrackBarGadget(#LPF_Ramp, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#HPF_Freq_Txt,  X,Y, 80,  16, "HPF Freq:",#PB_Text_Right)
  TrackBarGadget(#HPF_Freq, X+90, Y, 100, 14, -100, 100, 1): Y+space :   
  TextGadget(#HPF_Ramp_Txt,  X,Y, 80,  16, "HPF Ramp:",#PB_Text_Right)
  TrackBarGadget(#HPF_Ramp, X+90, Y, 100, 14, -100, 100, 1): Y+space+5 :   
  AddKeyboardShortcut(1,#PB_Shortcut_1,#Control_Frame)
  AddKeyboardShortcut(1,#PB_Shortcut_R,#Random)
  AddKeyboardShortcut(1,#PB_Shortcut_P,#Play)
    AddKeyboardShortcut(1,#PB_Shortcut_M,#Mutate)
    AddKeyboardShortcut(1,#PB_Shortcut_2,#Import_Frame)
    AddKeyboardShortcut(1,#PB_Shortcut_L,#Load_sfs)
    AddKeyboardShortcut(1,#PB_Shortcut_S,#Load_Seed)
    AddKeyboardShortcut(1,#PB_Shortcut_W,#Load_B64)
    AddKeyboardShortcut(1,#PB_Shortcut_O,#LoadfromClipboard)
    AddKeyboardShortcut(1,#PB_Shortcut_C,#SaveToClipboard)
    AddKeyboardShortcut(1,#PB_Shortcut_3,#Presets_Frame)
    AddKeyboardShortcut(1,#PB_Shortcut_N,#Coin)
    AddKeyboardShortcut(1,#PB_Shortcut_A,#Laser)
    AddKeyboardShortcut(1,#PB_Shortcut_E,#Explosion)
    AddKeyboardShortcut(1,#PB_Shortcut_U,#PowerUp)
    AddKeyboardShortcut(1,#PB_Shortcut_H,#Hit)
    AddKeyboardShortcut(1,#PB_Shortcut_J,#Jump)
    AddKeyboardShortcut(1,#PB_Shortcut_B,#Blip)
    AddKeyboardShortcut(1,#PB_Shortcut_T,42)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_1,#Control_Frame)
  AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_R,#Random)
  AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_P,#Play)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_M,#Mutate)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_2,#Import_Frame)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_L,#Load_sfs)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_S,#Load_Seed)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_W,#Load_B64)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_A,#LoadfromClipboard)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_C,#SaveToClipboard)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_3,#Presets_Frame)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_N,#Coin)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_A,#Laser)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_E,#Explosion)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_U,#PowerUp)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_H,#Hit)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_J,#Jump)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_B,#Blip)
    AddKeyboardShortcut(1,#PB_Shortcut_Alt | #PB_Shortcut_T,42)
    
  EndProcedure

InitSound()


OpenWindow(1,0,0,1024,540,"Retroar FX Generator",#PB_Window_ScreenCentered)
Init_Gadgets()
SetActiveGadget(#Random)
SetValues()
            Randomize()
            Update = 1
Repeat
  ;Repeat
    EventID.i = WaitWindowEvent(1)
    Select EventID 
      Case #PB_Event_CloseWindow
        End
      Case #PB_Event_Gadget
        ProcessGUI(EventGadget())
    Case  #PB_Event_Menu
  ProcessGUI(EventMenu())
  EndSelect
  ;Until EventID = 0
  If Update > 0
    B64String = Base64Enc()
        SpotFX_Create(B64String,0)
    SoundVolume(0, 60) : StopSound(0):PlaySound(0)
    Update = 0
  EndIf
    ForEver 
End

Procedure ProcessGUI(event.l)
    Select Event
        ;Case 42
                        ;SetActiveGadget(#Combobox_WaveType)
                ; Sound control
          Case #Random
            Randomize()
            Update = 1
          Case #Play
            StopSound(0)
            PlaySound(0)
          Case #Load_sfs
                        LoadSFS()
            SetValues()
            Update = 1
          Case #Load_Seed
SaveSFS(savereq("Save sound","Dragonflame Sound FX", "dsx"))
          Case #Load_B64
          SaveWav()  
        Case #LoadfromClipboard
          B64String=GetClipboardText()
          SpotFX_Decode(B64String)
  SetValues()
  update=1
Case #SaveToClipboard
  SetClipboardText(B64String)
Case #Mutate
            Mutate() : SetValues() : Update=1
          Case #Coin
            ResetParams();
            With SFX_Wave
              \p_base_freq=0.4+SpotFX_Rnd(0.5);
              \p_env_attack=0.0;
              \p_env_sustain=SpotFX_Rnd(0.1);
              \p_env_decay=0.1+SpotFX_Rnd(0.4);
              \p_env_punch=0.3+SpotFX_Rnd(0.3);
              If Random(1)
                \p_arp_speed=0.5+SpotFX_Rnd(0.2);
                \p_arp_mod=0.2+SpotFX_Rnd(0.4);
              EndIf
            EndWith 
            SetValues()
            Update = 1
          Case #Laser
            ResetParams();
            With SFX_Wave
              \wave_type =Random(2);
              If \wave_type=2 And Random(1) : \wave_type=Random(1) : EndIf
              \p_base_freq=0.5+SpotFX_Rnd(0.5);
              \p_freq_limit=\p_base_freq-0.2-SpotFX_Rnd(0.6);
              If \p_freq_limit<0.2 : \p_freq_limit=0.2 : EndIf
              \p_freq_ramp=-0.15-SpotFX_Rnd(0.2);
              If Random(2)=0
                \p_base_freq=0.3+SpotFX_Rnd(0.6);
                \p_freq_limit=SpotFX_Rnd(0.1);
                \p_freq_ramp=-0.35-SpotFX_Rnd(0.3);
              EndIf
              If Random(1)
                \p_duty=SpotFX_Rnd(0.5);
                \p_duty_ramp=SpotFX_Rnd(0.2);
              Else
                \p_duty=0.4+SpotFX_Rnd(0.5);
                \p_duty_ramp=-SpotFX_Rnd(0.7);
              EndIf
              \p_env_attack=0.0;
              \p_env_sustain=0.1+SpotFX_Rnd(0.2);
              \p_env_decay=SpotFX_Rnd(0.4);
              If Random(1) : \p_env_punch=SpotFX_Rnd(0.3) : EndIf
              If Random(2)=0
                \p_pha_offset=SpotFX_Rnd(0.2);
                \p_pha_ramp=-SpotFX_Rnd(0.2);
              EndIf
              If Random(1) : \p_hpf_freq=SpotFX_Rnd(0.3) : EndIf
            EndWith
            SetValues()
            Update = 1
          Case #Jump
            ResetParams();
            With SFX_Wave
              \wave_type=0;
              \p_duty=SpotFX_Rnd(0.6);
              \p_base_freq=0.3+SpotFX_Rnd(0.3);
              \p_freq_ramp=0.1+SpotFX_Rnd(0.2);
              \p_env_attack=0.0;
              \p_env_sustain=0.1+SpotFX_Rnd(0.3);
              \p_env_decay=0.1+SpotFX_Rnd(0.2);
              If(Random(1))
                \p_hpf_freq=SpotFX_Rnd(0.3);
              EndIf
              If(Random(1))
                \p_lpf_freq=1.0-SpotFX_Rnd(0.6);
              EndIf
              
            EndWith 
            SetValues()
            Update = 1
          Case #Explosion
            ResetParams();
            With SFX_Wave
              ResetParams();
              \wave_type=3;
              If(Random(1))
                \p_base_freq=0.1+SpotFX_Rnd(0.4);
                \p_freq_ramp=-0.1+SpotFX_Rnd(0.4);
              Else
                \p_base_freq=0.2+SpotFX_Rnd(0.7);
                \p_freq_ramp=-0.2-SpotFX_Rnd(0.2);
              EndIf
              \p_base_freq*\p_base_freq;
              If(Random(4)=0) : \p_freq_ramp=0.0 : EndIf
              If(Random(2)=0) : \p_repeat_speed=0.3+SpotFX_Rnd(0.5) : EndIf
              \p_env_attack=0.0;
              \p_env_sustain=0.1+SpotFX_Rnd(0.3);
              \p_env_decay=SpotFX_Rnd(0.5);
              If(Random(1)=0)
                \p_pha_offset=-0.3+SpotFX_Rnd(0.9);
                \p_pha_ramp=-SpotFX_Rnd(0.3);
              EndIf
              \p_env_punch=0.2+SpotFX_Rnd(0.6);
              If(Random(1))
                \p_vib_strength=SpotFX_Rnd(0.7);
                \p_vib_speed=SpotFX_Rnd(0.6);
              EndIf
              If(Random(2)=0)
                \p_arp_speed=0.6+SpotFX_Rnd(0.3);
                \p_arp_mod=0.8-SpotFX_Rnd(1.6);
              EndIf
            EndWith 
            SetValues()
            Update = 1
          Case #Hit
            ResetParams();
            With SFX_Wave
              \wave_type=Random(2);
              If(\wave_type=2)
                \wave_type=3;
              EndIf
              If(\wave_type=0)
                \p_duty=SpotFX_Rnd(0.6);
              EndIf
              \p_base_freq=0.2+SpotFX_Rnd(0.6);
              \p_freq_ramp=-0.3-SpotFX_Rnd(0.4);
              \p_env_attack=0.0;
              \p_env_sustain=SpotFX_Rnd(0.1);
              \p_env_decay=0.1+SpotFX_Rnd(0.2);
              If(Random(1))
                \p_hpf_freq=SpotFX_Rnd(0.3);
              EndIf
            EndWith 
            SetValues()
            Update = 1
          Case #PowerUp
            ResetParams();
            With SFX_Wave
              If(Random(1))
                \wave_type=1;
              Else
                \p_duty=SpotFX_Rnd(0.6);
              EndIf
              If(Random(1)) 
                \p_base_freq=0.2+SpotFX_Rnd(0.3);
                \p_freq_ramp=0.1+SpotFX_Rnd(0.4);
                \p_repeat_speed=0.4+SpotFX_Rnd(0.4);
              Else
                \p_base_freq=0.2+SpotFX_Rnd(0.3);
                \p_freq_ramp=0.05+SpotFX_Rnd(0.2);
              EndIf
              
              If(Random(1))
                \p_vib_strength=SpotFX_Rnd(0.7);
                \p_vib_speed=SpotFX_Rnd(0.6);
              EndIf
              \p_env_attack=0.0
              \p_env_sustain=SpotFX_Rnd(0.4);
              \p_env_decay=0.1+SpotFX_Rnd(0.4);
            EndWith 
            SetValues()
            Update = 1
          Case #Blip
            ResetParams();
            With SFX_Wave
              \wave_type=Random(1)
              If \wave_type=0 : \p_duty=SpotFX_Rnd(0.6) : EndIf
              \p_base_freq=0.2+SpotFX_Rnd(0.4);
              \p_env_attack=0.0;
              \p_env_sustain=0.1+SpotFX_Rnd(0.1);
              \p_env_decay=SpotFX_Rnd(0.2);
              \p_hpf_freq=0.1;
            EndWith 
            SetValues()
            Update = 1
        Case #SuperSamples To #HPF_Ramp
            GetValues()
            Update = 1
          Case #Control_Frame
            SetActiveGadget(#random)
          Case #Import_Frame
            SetActiveGadget(#Load_sfs)
          Case #Presets_Frame
            SetActiveGadget(#Coin)
          EndSelect
                EndProcedure
                
Procedure SettabsTop(gadget.l)
           Protected style.i 
           
           style = GetWindowLong_(GadgetID(gadget),#GWL_STYLE)
   style + #WS_TABSTOP
   SetWindowLong_(GadgetID(gadget),#GWL_STYLE,style)
      SetProp_(GadgetID(gadget),"obj",*obj)
    
    EndProcedure
    
    Procedure SaveWav()
    Protected fn.s=savereq("Save Wave Sound","Wave Sound", "wav")
            If fn
                            spotfx_create(B64String,0,0,fn)
            EndIf
            
    EndProcedure
    
    Procedure.s savereq(title.s,msg.s,ext.s)
  Protected ok.b=0, fn.s
  
  Repeat
  fn=SaveFileRequester(title,"",msg + " (*." + ext + ")|*." + ext,0)
  If GetExtensionPart(fn)<>ext And fn<>"":fn+"."+ext:EndIf

  If fn And fn<>"."+ext
    If FileSize(fn)<>-1
      If MessageRequester("File exists","The file '"+fn+"' already exists. Would you like to overwrite it?",#PB_MessageRequester_YesNo)=#PB_MessageRequester_Yes
        ok=1
      Else
        ok=0
        EndIf
      Else
        ok=1
        EndIf
        Else
        ProcedureReturn #Null$
  EndIf  
  Until ok
ProcedureReturn fn
EndProcedure

; IDE Options = PureBasic 5.70 LTS (Windows - x64)
; CursorPosition = 497
; FirstLine = 312
; Folding = fk-
; Executable = rfx_gen64.exe
; Compiler = PureBasic 5.70 LTS (Windows - x64)
; EnableCompileCount = 15
; EnableBuildCount = 3