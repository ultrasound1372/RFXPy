;/ SpotFX - PB Conversion of SFXR, by Dr Petter. PJames.08.


;/ Spotfx 2b
;/ Changelog 2b:
;/ Split generator code from application code
;/ Changelog 2a:
;/ Fixed Base64encoder error
;/ Added sample rate slider, now have choice of 8 sample rates
;/ reduced code size

Structure SpotFX_WAVE_Header
  wFormatTag.w 
  nChannels.w 
  nSamplesPerSec.l
  nAvgBytesPerSec.l
  nBlockAlign.w 
  wBitsPerSample.w 
  cbSize.w 
EndStructure

Structure GenBits
  wave_type.i: p_base_freq.f: p_freq_limit.f: p_freq_ramp.f: p_freq_dramp.f: p_duty.f
  p_duty_ramp.f: p_vib_strength.f: p_vib_speed.f: p_vib_delay.f: p_env_attack.f: p_env_sustain.f
  p_env_decay.f: p_env_punch.f: p_lpf_resonance.f: p_lpf_freq.f: p_lpf_ramp.f
  p_hpf_freq.f: p_hpf_ramp.f: p_pha_offset.f: p_pha_ramp.f: p_repeat_speed.f: p_arp_speed.f: p_arp_mod.f
  SuperSample.b : Sample_Rate.b
EndStructure
Structure SpotFX_SFXRWave Extends GenBits
  phase.i: playing_sample.i :  env_time.i
  fperiod.d: rfperiod.f : fmaxperiod.d : fslide.d : fdslide.d : period.i : square_duty.f : square_slide.f : env_stage.i
  env_vol.f: fphase.f: fdphase.f: iphase.i: ipp.i: fltp.f: fltdp.f: fltw.f: fltw_d.f: fltdmp.f: fltphp.f: flthp.f
  flthp_d.f: vib_phase.f: vib_speed.f: vib_amp.f: rep_time.i: rep_limit.i: arp_time.i: arp_limit.i: arp_mod.d
  filter_on.b: 
  SFX_env_length.i[4] : SFX_phaser_buffer.f[1025] : SFX_noise_buffer.f[33] 
  Mutate.a : Sound_playing.i
EndStructure

Global SFX_WaveFormatEx.SpotFX_WAVE_Header
Global SFX_Wave.SpotFX_SFXRWave
Global B64Gen.GenBits

Macro SpotFX_Rnd(range)
  (Random(10000.0)/10000.0)*range;
EndMacro

Procedure SpotFX_Decode(Txt.s)
  Protected *mem, *dec
  *mem = AllocateMemory(1024)
  *dec = AllocateMemory(1024)
  PokeS(*mem,Txt,StringByteLength(Txt),#PB_Ascii)
  Base64DecoderBuffer(*mem, StringByteLength(Txt), *dec, SizeOf(GenBits))
  CopyMemory(*dec,@B64Gen,SizeOf(GenBits))
  CopyMemory(*dec,@SFX_Wave,SizeOf(GenBits))
  FreeMemory(*mem) : FreeMemory(*dec)
EndProcedure
Procedure SpotFX_ResetSample(restart.b)
  Protected tmp.d, Loop.i, Alength.i
  
  With SFX_Wave
    If Not restart : \phase=0 : EndIf
    \fperiod= 100.0/((\p_base_freq * \p_base_freq)+0.001)
    \period=Int(\fperiod)
    
    \fmaxperiod=100.0/((\p_freq_limit*\p_freq_limit)+0.001);
    
    \fslide= 1.0-Pow(\p_freq_ramp,3)*0.01;
    \fdslide= -Pow(\p_freq_dramp,3)*0.000001;
    
    \square_duty=0.5-\p_duty*0.5;
    \square_slide=-\p_duty_ramp*0.00005;
    
    If \p_arp_mod >= 0
      \arp_mod=1.0 - Pow(\p_arp_mod,2.0)*0.9
    Else
      \arp_mod=1.0 + Pow(\p_arp_mod,2.0) * 10.0
    EndIf
    
    \arp_time = 0
    \arp_limit = Int(Pow(1.0 - \p_arp_speed, 2.0) * 20000 + 32)
    If \p_arp_speed=1.0
      \arp_limit=0;
    EndIf
    
    If Not restart
      ;      Alength = 0
      ;// reset filter
      \fltp=0
      \fltdp=0
      \fltw=Pow(\p_lpf_freq,3)*0.1;
      \fltw_d=1.0+\p_lpf_ramp*0.0001;
      \fltdmp=5.0/(1.0+Pow(\p_lpf_resonance,2)*20.0)*(0.01+\fltw);
      If \fltdmp>0.8 : \fltdmp=0.8 : EndIf
      \fltphp=0.0;
      \flthp=Pow(\p_hpf_freq,2)*0.1;
      \flthp_d=1.0+\p_hpf_ramp*0.0003;
      ;// reset vibrato
      \vib_phase=0.0;
      \vib_speed=Pow(\p_vib_speed,2)*0.01;
      \vib_amp=\p_vib_strength*0.5;
      ;// reset envelope
      \env_vol=0.0;
      \env_stage=0;
      \env_time=0;
      
      \SFX_env_length[0]=Int(\p_env_attack*\p_env_attack*100000.0)
      \SFX_env_length[1]=Int(\p_env_sustain*\p_env_sustain*100000.0)
      \SFX_env_length[2]=Int(\p_env_decay*\p_env_decay*100000.0)
      
      \fphase=Pow(\p_pha_offset,2.0)*1020.0;
      If \p_pha_offset<0.0 : \fphase=-\fphase : EndIf
      \fdphase=Pow(\p_pha_ramp,2.0)*1.0;
      If \p_pha_ramp<0.0 : \fdphase=-\fdphase : EndIf
      \iphase=Abs(Int(\fphase))
      
      \ipp=0
      For Loop = 0 To 1024 : \SFX_phaser_buffer[Loop]=0.0 : Next
      For Loop = 0 To 32 : \SFX_noise_buffer[Loop]= SpotFX_Rnd(2)-1 : Next
      
      \rep_time=0;
      \rep_limit= Int(Pow(1.0 - \p_repeat_speed, 2.0) * 20000 + 32)
      If \p_repeat_speed=0.0 : \rep_limit=0 : EndIf
    EndIf
  EndWith
EndProcedure
Procedure.l SpotFX_Create(SFXData.s, Sample_Number.i, *memcopy = 0, SaveFile.s = "")
  Protected Mutate.i, *Sample_Memory_Alloc, *ms, i.i, rfperiod.f,  ssample.f, si.i, sample.f, T.i, fp.f, pp.f, SLength.i, Alength.i, PowTmp.f
  Protected Sample_Min.f, Sample_Max.f, Sample_Div.f, MyLoop.i, SuperSample.f, Sample_Rate.i, snd.l
  SpotFX_Decode(SFXData)
  
  With SFX_Wave
Sample_Rate = 44100
\playing_sample = #True
    \arp_time = 0
    SpotFX_ResetSample(#False);
    *Sample_Memory_Alloc = AllocateMemory(768000)
    *ms = *Sample_Memory_Alloc 
    
    Dim Temp.d(768000)
    CompilerIf #PB_Compiler_OS = #PB_OS_MacOS
      \SFX_WaveFormatEx\wFormatTag = 1
    CompilerElse
      SFX_WaveFormatEx\wFormatTag = #WAVE_FORMAT_PCM; 
    CompilerEndIf
    
    SFX_WaveFormatEx\nChannels =$0001; 
    SFX_WaveFormatEx\nSamplesPerSec = Sample_Rate;22050 / 2;  44100 ; 
    SFX_WaveFormatEx\wBitsPerSample = $0010; 
    SFX_WaveFormatEx\nBlockAlign = (SFX_WaveFormatEx\nChannels * SFX_WaveFormatEx\wBitsPerSample) /8 
    SFX_WaveFormatEx\nAvgBytesPerSec = SFX_WaveFormatEx\nSamplesPerSec * SFX_WaveFormatEx\nBlockAlign; 
    SFX_WaveFormatEx\cbSize = 0
    PokeS(*ms,"RIFF",4,#PB_Ascii):*ms+4  ;'RIFF'
    *ms + 4 ;/ skip file data size until its known
    PokeS(*ms,"WAVE",4,#PB_Ascii):*ms+4  ;'WAVE' 
    PokeS(*ms,"fmt ",4,#PB_Ascii):*ms+4  ;'fmt ' 
    PokeL(*ms,SizeOf(SpotFX_WAVE_Header)):*ms+4  ;TWaveFormat data size 
    PokeW(*ms,SFX_WaveFormatEx\wFormatTag):*ms+2; SFX_WaveFormatEx record 
    PokeW(*ms,SFX_WaveFormatEx\nChannels):*ms+2 
    PokeL(*ms,SFX_WaveFormatEx\nSamplesPerSec):*ms+4 
    PokeL(*ms,SFX_WaveFormatEx\nAvgBytesPerSec):*ms+4 
    PokeW(*ms,SFX_WaveFormatEx\nBlockAlign):*ms+2 
    PokeW(*ms,SFX_WaveFormatEx\wBitsPerSample):*ms+2 
    PokeW(*ms,SFX_WaveFormatEx\cbSize):*ms+2 
    PokeS(*ms,"data",4,#PB_Ascii):*ms+4  ;'data' 
    Debug "Header Size: "+Str(*Sample_Memory_Alloc - *ms)
    Sample_Min = 999999 : Sample_Max = -999999 ;/ for normalizing
    
    Repeat
      If Not \playing_sample 
        Break
      EndIf
      \rep_time + 1;
      If \rep_limit <> 0 And \rep_time >= \rep_limit 
        \rep_time = 0;
        SpotFX_ResetSample(#True);
      EndIf
      ;/ frequency envelopes/arpeggios
      \arp_time+1
      If \arp_limit <> 0 And \arp_time>=\arp_limit 
        \arp_limit=0;
        \fperiod * \arp_mod;
      EndIf
      
      \fslide + \fdslide;
      \fperiod * \fslide;
      If \fperiod>\fmaxperiod 
        \fperiod=\fmaxperiod;
        If \p_freq_limit>0
          \playing_sample=#False;
          Break
        EndIf
      EndIf
      \rfperiod=\fperiod
      If \vib_amp>0
        \vib_phase+\vib_speed;
        \rfperiod=\fperiod*(1.0+Sin(\vib_phase)*\vib_amp);
      EndIf
      \period=Int(\rfperiod)
      If \period<8 : \period=8 : EndIf
      \square_duty+\square_slide;
      If \square_duty<0  : \square_duty=0 : EndIf
      If \square_duty>0.5  : \square_duty=0.5 : EndIf
      ;// volume envelope
      \env_time+1;
      
      If \env_time>\SFX_env_length[\env_stage]
        \env_time=0;
        \env_stage+1;
        If \env_stage=3 
          \playing_sample=#False;
          Break
        EndIf
      EndIf
      Select \env_stage
        Case 0 
          \env_vol=(\env_time / \SFX_env_length[0]);
        Case 1 
          \env_vol=1.0+(Pow(1.0-\env_time / \SFX_env_length[1], 1.0)*2.0*\p_env_punch);
        Case 2
          \env_vol=1.0-(\env_time / \SFX_env_length[2]);
      EndSelect
      
      ;// phaser step
      \fphase+\fdphase;
      \iphase=Abs(Int(\fphase));
      If \iphase>1023 : \iphase=1023 : EndIf
      If \flthp_d <> 0
        \flthp * \flthp_d;
        If \flthp<0.00001 : \flthp=0.00001 : EndIf
        If \flthp>0.1 : \flthp=0.1 : EndIf
      EndIf
      
      ssample.f=0.0 : sample=0.0
      
      For si=0 To \SuperSample ;// 8x supersampling X now randomized
        
        \phase+1;
        If \phase>=\period 
          \phase % \period;
          If \wave_type=3 
            For i=0 To 31 : \SFX_noise_buffer[i]=SpotFX_Rnd(2.0)-1.0 : Next
          EndIf
        EndIf
        ;// base waveform
        fp = \phase / \period
        Select \wave_type
          Case 0: ;// square
            If fp < \square_duty 
              sample=0.5
            Else
              sample=-0.5
            EndIf
          Case 1: ;// sawtooth
            sample=1.0-fp*2.0;
          Case 2: ;// sine
            sample=Sin(fp*2.0*#PI);
          Case 3: ;// noise
            sample=\SFX_noise_buffer[\phase*32 / \period];
        EndSelect  
        ;// lp filter
        pp.f=\fltp
        \fltw * \fltw_d;
        If \fltw<0.0 : \fltw=0.0 : EndIf
        If \fltw>0.1 : \fltw=0.1 : EndIf
        If \p_lpf_freq <> 1.0
          \fltdp+((sample-\fltp)*\fltw);
          \fltdp-(\fltdp*\fltdmp);
        Else
          \fltp=sample;
          \fltdp=0.0
        EndIf
        \fltp + \fltdp;
        ;// hp filter
        \fltphp + (\fltp-pp);
        \fltphp - (\fltphp * \flthp);
        sample = \fltphp;
        ;// phaser
        \SFX_phaser_buffer[\ipp&1023]=sample;
        sample+\SFX_phaser_buffer[(\ipp-\iphase+1024)&1023];
        \ipp=(\ipp+1)&1023;
        
        ;// final accumulation and envelope application
        ssample = ssample + sample * \env_vol;
      Next
      ssample / (\SuperSample+1)
      
      SLength + 1  : Alength+2
      Temp(SLength) = ssample
      If ssample > Sample_Max : Sample_Max = ssample : EndIf
      If ssample < Sample_Min : Sample_Min = ssample : EndIf
      
    ForEver
    ; 
    SLength + 1 : Alength + 2
    Repeat
      SLength - 1 : Alength -2
    Until Abs(Temp(SLength)) > 0.001 Or SLength =< 1024
    
    ;/ Normalize & store final sample data
    Sample_Div = Abs(Sample_Max)
    If Abs(Sample_Min) > Sample_Div : Sample_Div = Abs(Sample_Min) : EndIf
    *ms+2
    For MyLoop.i = 1 To SLength
      *ms+2
      PokeW(*ms,(Temp(MyLoop) / Sample_Div) * 32000)
    Next
    PokeL(*Sample_Memory_Alloc+42,Alength) ;/sound data size
    PokeL(*Sample_Memory_Alloc+4,Alength+36):
    ;/ Store
if SaveFile=""
snd=CatchSound(Sample_Number,*Sample_Memory_Alloc,Alength)
    Debug "Caught Sound - Length: "+Str(Alength)
endIf    
;/ for visual waveform routine
    If *memcopy > 0
      PokeL(*memcopy,Alength) ;/ store waveform length in the first 4 bytes
      CopyMemory(*Sample_Memory_Alloc+46,*memcopy+4,Alength)
    EndIf
    ;/ Save Wav File
    If SaveFile <> ""
      If CreateFile(1,SaveFile)
        WriteData(1,*Sample_Memory_Alloc,Alength+46)
        CloseFile(1)
      EndIf
    EndIf
    
    FreeMemory(*Sample_Memory_Alloc) : Dim Temp(0)
  EndWith
ProcedureReturn snd  
EndProcedure

; IDE Options = PureBasic 5.73 LTS (Windows - x86)
; CursorPosition = 51
; FirstLine = 47
; Folding = -
; EnableThread
; EnableXP
; EnableOnError
; EnableCompileCount = 1
; EnableBuildCount = 0