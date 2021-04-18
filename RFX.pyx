# -*- coding: UTF-8 -*-
# cython: language_level=3
# cython port of Spotfx2b include.pbi, the purebasic include for Dragonflame RFXGen
# This is done with cython to achieve better performance, since we're just manipulating c types like ints, doubles, and arrays.

from libc.stdlib cimport rand, RAND_MAX, srand
from libc cimport time
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free # So I'm not creating a humungus array on the stack
import wave, io # To return a wave file as a bytestring
import base64, struct # To pack and unpack the RFXGen structure format
import binascii # for the exception raised by base64

# We need some math functions and constants, might as well get them from c.
cdef extern from *:
    """
    #define _USE_MATH_DEFINES
    #include <math.h>
    double clamp(double d, double min, double max) {
        return d < min ? min : d > max ? max : d;
    }
    double frac(double x) {
        return x-floor(x);
    }
    """
    double clamp(double d, double min, double max)
    double frac(double x)
    cdef double PI "M_PI"
    cdef double INFINITY "INFINITY"

from libc.math cimport pow, sin, round, sqrt, abs, fabs, ceil, floor, isinf

# pack structure
GenBitsS=[
    struct.Struct("<i23f2B"), # version 0, RFXGen compatible
    struct.Struct("<3sBi23d2B") # v1, supports wider wave_type range, stores with doubles instead of floats, and includes header
    ]

# Eventually we're going to have to encode an array of floats into 16-bit integers to plop into a wave file.
pcm16=struct.Struct("<h")

# to track the status of calls to srand, we only need the one.
sranded=0

cpdef double Rnd(double a=1.0) nogil:
    return a*(<double>rand()/<double>RAND_MAX)

cpdef bint RndBool() nogil:
    return <bint>round(Rnd(1.0))

cpdef double mrnd() nogil:
    return Rnd(0.1)-0.05

# some exceptions that can be thrown

class Error(Exception):
    pass

class InvalidDataError(Error,ValueError):
    pass

class NewerDataError(Error,RuntimeError):
    pass

cdef class GenBits:
    cdef public:
        int wave_type
        double p_base_freq, p_freq_limit, p_freq_ramp, p_freq_dramp, p_duty
        double p_duty_ramp, p_vib_strength, p_vib_speed, p_vib_delay, p_env_attack, p_env_sustain
        double p_env_decay, p_env_punch, p_lpf_resonance, p_lpf_freq, p_lpf_ramp
        double p_hpf_freq, p_hpf_ramp, p_pha_offset, p_pha_ramp, p_repeat_speed, p_arp_speed, p_arp_mod
        char SuperSample, Sample_Rate
    max_wave_type=8
    
    @classmethod
    def headVersion(cls,data):
        """Internal function to return the version specified in the header of the decoded data, or 0 if it could not be determined due to lack of such a header.
            
            Note that returning 0 does not mean the data is valid version 0 data, it must still be parsed with the version 0 structure to determine that.
            ValueError will be raised if the data is less than 4 bytes long or the first 4 bytes don't look like either a header or the first 4 bytes of a v0 structure.
        """
        try:
            magic, version=struct.unpack_from("3sB",data)
            if magic!=b'FXP':
                if data[1:4]==b'\x00\x00\x00':
                    # possibly version 0 data since the waveform type fits in a byte but uses 4 to store it in little endion
                    if data[0] <=3: return 0
                    else: raise ValueError("Invalid assumed waveform type for v0 structure")
                else: raise ValueError("No header and not a v0 structure.")
            else: return version
        except (IndexError, struct.error): raise ValueError("Data not long enough")
    
    def load(self, encdata):
        try:
            data=base64.b64decode(encdata.encode('ascii'))
            version=self.headVersion(data)
            if version>=len(GenBitsS): raise NewerDataError
            values=GenBitsS[version].unpack(data)
            if version>0: values=values[2:] # trim header off
            (self.wave_type, self.p_base_freq, self.p_freq_limit, self.p_freq_ramp, self.p_freq_dramp, self.p_duty, self.p_duty_ramp, self.p_vib_strength, self.p_vib_speed, self.p_vib_delay, self.p_env_attack, self.p_env_sustain, self.p_env_decay, self.p_env_punch, self.p_lpf_resonance, self.p_lpf_freq, self.p_lpf_ramp, self.p_hpf_freq, self.p_hpf_ramp, self.p_pha_offset, self.p_pha_ramp, self.p_repeat_speed, self.p_arp_speed, self.p_arp_mod, self.SuperSample, self.Sample_Rate)=values
        except (binascii.Error, struct.error, ValueError, UnicodeEncodeError) as exc:
            raise InvalidDataError from exc
        except NewerDataError as exc: raise exc
    
    def save(self):
        values=(b'FXP', len(GenBitsS)-1, self.wave_type, self.p_base_freq, self.p_freq_limit, self.p_freq_ramp, self.p_freq_dramp, self.p_duty, self.p_duty_ramp, self.p_vib_strength, self.p_vib_speed, self.p_vib_delay, self.p_env_attack, self.p_env_sustain, self.p_env_decay, self.p_env_punch, self.p_lpf_resonance, self.p_lpf_freq, self.p_lpf_ramp, self.p_hpf_freq, self.p_hpf_ramp, self.p_pha_offset, self.p_pha_ramp, self.p_repeat_speed, self.p_arp_speed, self.p_arp_mod, self.SuperSample, self.Sample_Rate)
        return base64.b64encode(GenBitsS[-1].pack(*values)).decode('ascii')
    
    cpdef ResetParams(self):
        self.SuperSample=8
        self.wave_type=0
        self.p_base_freq=0.3
        self.p_freq_limit=self.p_freq_ramp=self.p_freq_dramp=self.p_duty=self.p_duty_ramp\
        =self.p_vib_strength=self.p_vib_speed=self.p_vib_delay=self.p_env_attack=self.p_env_punch\
        =self.p_lpf_resonance=self.p_lpf_ramp=self.p_hpf_freq=self.p_hpf_ramp=self.p_pha_offset=self.p_pha_ramp\
        =self.p_repeat_speed=self.p_arp_speed=self.p_arp_mod=0.0
        self.p_env_sustain=0.3
        self.p_env_decay=0.4
    
    @classmethod
    def randomize(cls):
        cdef GenBits ret=cls()
        ret.wave_type=<int>round(Rnd(3))
        ret.p_base_freq=pow(Rnd(2.0)-1.0,2.0)
        if RndBool():
            ret.p_base_freq=pow(Rnd(2.0)-1.0,3.0)+0.5
        ret.p_freq_limit=0
        ret.p_freq_ramp=pow(Rnd(2.0)-1.0,5.0)
        if ret.p_base_freq>0.7 and ret.p_freq_ramp>0.2:
            ret.p_freq_ramp=-ret.p_freq_ramp
        if ret.p_base_freq<0.2 and ret.p_freq_ramp<-0.05:
            ret.p_freq_ramp=-ret.p_freq_ramp
        ret.p_freq_dramp=pow(Rnd(2.0)-1.0,3.0)
        ret.p_duty=Rnd(2.0)-1.0
        ret.p_duty_ramp=pow(Rnd(2.0)-1.0,3.0)
        ret.p_vib_strength=pow(Rnd(2.0)-1.0,3.0)
        ret.p_vib_speed=Rnd(2.0)-1.0
        ret.p_vib_delay=Rnd(2.0)-1.0
        ret.p_env_attack=pow(Rnd(2.0)-1.0,3.0)
        ret.p_env_sustain=pow(Rnd(2.0)-1.0,2.0)
        ret.p_env_decay=Rnd(2.0)-1.0
        ret.p_env_punch=pow(Rnd(0.8),2.0)
        if ret.p_env_attack+ret.p_env_sustain+ret.p_env_decay<0.2:
            ret.p_env_sustain+=(0.2+Rnd(0.3))
            ret.p_env_decay+=(0.2+Rnd(0.3))
        ret.p_lpf_resonance=Rnd(2.0)-1.0
        ret.p_lpf_freq=1.0-pow(Rnd(1.0),3.0)
        ret.p_lpf_ramp=pow(Rnd(2.0)-1.0,3.0)
        if ret.p_lpf_freq<0.1 and ret.p_lpf_ramp<-0.05:
            ret.p_lpf_ramp=-ret.p_lpf_ramp
        ret.p_hpf_freq=pow(Rnd(1.0),5.0)
        ret.p_hpf_ramp=pow(Rnd(2.0)-1.0,5.0)
        ret.p_pha_offset=pow(Rnd(2.0)-1.0,3.0)
        ret.p_pha_ramp=pow(Rnd(2.0)-1.0,3.0)
        ret.p_repeat_speed=Rnd(2.0)-1.0
        ret.p_arp_speed=Rnd(2.0)-1.0
        ret.p_arp_mod=Rnd(2.0)-1.0
        ret.SuperSample=<int>(round(Rnd(14))+2)
        return ret

# These variables aren't in the exact same order as in the PB code due to type groupings. I think casting will sort things out, though.
cdef class SFXRWave(GenBits):
    cdef:
        int phase, playing_sample, env_time, period, env_stage, iphase, ipp, rep_time, rep_limit, arp_time, arp_limit, Sound_playing
        double rfperiod, square_duty, square_slide, env_vol, fphase, fdphase, fltp, fltdp, fltw, fltw_d, fltdmp, fltphp, flthp, flthp_d, vib_phase, vib_speed, vib_amp
        double fperiod, fmaxperiod, fslide, fdslide, arp_mod
        char filter_on # May actually be bint
        int SFX_env_length[4]
        double* SFX_phaser_buffer
        double SFX_noise_buffer[33]
        double SFX_pink_noise_buffer[7]
        unsigned short SFX_LFSR
    
    def __cinit__(self):
        global sranded
        if sranded==0:
            srand(<unsigned int>time.time(NULL))
            sranded=1
        self.SFX_phaser_buffer=<double*>PyMem_Malloc(1025*sizeof(double))
        if not self.SFX_phaser_buffer:
            raise MemoryError()
    
    def __dealloc__(self):
        PyMem_Free(self.SFX_phaser_buffer)
    
    @classmethod
    def randomize(cls):
        ret=cls()
        ret.load(super().randomize().save())
        return ret
    
    @classmethod
    cpdef fromGenBits(cls,gb):
        cdef SFXRWave ret=cls()
        ret.load(gb.save())
        return ret
    
    cpdef toGenBits(self):
        cdef GenBits ret=GenBits()
        ret.load(self.save())
        return ret
    
    def __copy__(self):
        ret=SFXRWave()
        ret.load(self.save())
        return ret
    
    cpdef mutate(self):
        cdef SFXRWave ret=self.__copy__()
        if RndBool(): ret.p_base_freq+=mrnd()
        if RndBool(): ret.p_freq_ramp+=mrnd()
        if RndBool(): ret.p_freq_dramp+=mrnd()
        if RndBool(): ret.p_duty+=mrnd()
        if RndBool(): ret.p_duty_ramp+=mrnd()
        if RndBool(): ret.p_vib_strength+=mrnd()
        if RndBool(): ret.p_vib_speed+=mrnd()
        if RndBool(): ret.p_vib_delay+=mrnd()
        if RndBool(): ret.p_env_attack+=mrnd()
        if RndBool(): ret.p_env_sustain+=mrnd()
        if RndBool(): ret.p_env_decay+=mrnd()
        if RndBool(): ret.p_env_punch+=mrnd()
        if RndBool(): ret.p_lpf_resonance+=mrnd()
        if RndBool(): ret.p_lpf_freq+=mrnd()
        if RndBool(): ret.p_lpf_ramp+=mrnd()
        if RndBool(): ret.p_hpf_freq+=mrnd()
        if RndBool(): ret.p_hpf_ramp+=mrnd()
        if RndBool(): ret.p_pha_offset+=mrnd()
        if RndBool(): ret.p_pha_ramp+=mrnd()
        if RndBool(): ret.p_repeat_speed+=mrnd()
        if RndBool(): ret.p_arp_speed+=mrnd()
        if RndBool(): ret.p_arp_mod+=mrnd()
        return ret
    
    
    # Actually calling the load method this inherits should just plop in the value nice and easy!
    # Let's make the processing functions methods in here instead, so I don't have to public all the variables for internal functions anyway
    cdef void ResetSample(SFXRWave self, bint restart) nogil:
        cdef double tmp
        cdef int Loop, Alength
        if not restart:
            self.phase=0
        self.fperiod= 100.0/((<double>self.p_base_freq**2)+0.001) # I assume +0.001 is to prevent division by 0?
        self.period=<int>self.fperiod # Is that a valid cast?
        self.fmaxperiod=100.0/((self.p_freq_limit*self.p_freq_limit)+0.001)
        self.fslide= 1.0-pow(self.p_freq_ramp,3)*0.01
        self.fdslide= -pow(self.p_freq_dramp,3)*0.000001
        self.square_duty=0.5-self.p_duty*0.5
        self.square_slide=-self.p_duty_ramp*0.00005
        if self.p_arp_mod >= 0:
            self.arp_mod=1.0 - pow(self.p_arp_mod,2.0)*0.9
        else:
            self.arp_mod=1.0 + pow(self.p_arp_mod,2.0) * 10.0
        self.arp_time = 0
        self.arp_limit = <int>(pow(1.0 - self.p_arp_speed, 2.0) * 20000 + 32)
        if self.p_arp_speed==1.0:
            self.arp_limit=0;
        if not restart:
            Alength = 0
            # reset filter
            self.fltp=0
            self.fltdp=0
            self.fltw=pow(self.p_lpf_freq,3)*0.1
            self.fltw_d=1.0+self.p_lpf_ramp*0.0001
            self.fltdmp=5.0/(1.0+pow(self.p_lpf_resonance,2)*20.0)*(0.01+self.fltw)
            if self.fltdmp>0.8: self.fltdmp=0.8
            self.fltphp=0.0
            self.flthp=pow(self.p_hpf_freq,2)*0.1
            self.flthp_d=1.0+self.p_hpf_ramp*0.0003
            # reset vibrato
            self.vib_phase=0.0
            self.vib_speed=pow(self.p_vib_speed,2)*0.01
            self.vib_amp=self.p_vib_strength*0.5
            # reset envelope
            self.env_vol=0.0
            self.env_stage=0
            self.env_time=0
            self.SFX_env_length[0]=<int>(self.p_env_attack*self.p_env_attack*100000.0)
            self.SFX_env_length[1]=<int>(self.p_env_sustain*self.p_env_sustain*100000.0)
            self.SFX_env_length[2]=<int>(self.p_env_decay*self.p_env_decay*100000.0)
            self.fphase=pow(self.p_pha_offset,2.0)*1020.0
            if self.p_pha_offset<0.0: self.fphase=-self.fphase
            self.fdphase=pow(self.p_pha_ramp,2.0) # There was a *1.0 here but what's that for?
            if self.p_pha_ramp<0.0: self.fdphase=-self.fdphase
            self.iphase=abs(<int>self.fphase)
            self.ipp=0
            # I offset these because I think pb's for loop from x to y are upper inclusive, based on how the code looks.
            for Loop in range(1025):
                self.SFX_phaser_buffer[Loop]=0.0
            Loop=0
            for Loop in range(33):
                self.SFX_noise_buffer[Loop]=Rnd(2.0)-1
            Loop=0
            for Loop in range(7):
                self.SFX_pink_noise_buffer[Loop]=0
            self.SFX_LFSR=1
            self.rep_time=0
            self.rep_limit= <int>(pow(1.0 - self.p_repeat_speed, 2.0) * 20000 + 32)
            if self.p_repeat_speed==0.0: self.rep_limit=0
    
    # The signature for Create will be slightly different.
    # We won't pass the encoded data, since you should have sent that into this object, memcopy, or SaveFile.
    # This will also return a bytes buffer instead of a pointer to one, since we assume you're calling this from within python.
    cpdef bytes Create(self):
        cdef:
            int i=0, si=0, T=0, SLength=0, Alength=0, MyLoop=0, Sample_Rate
            double rfperiod, ssample=0, sample=0, fp, pp, PowTmp, Sample_Div, SuperSample, prevfp=0, curfp=0, prevRandom=0, curRandom=0, ntemp=0
            bint dirty=0 # For infinity emulation
        Sample_Rate=44100
        self.playing_sample=True
        self.arp_time=0
        self.ResetSample(False)
        cdef double *Temp=<double*>PyMem_Malloc(768000*sizeof(double))
        if not Temp:
            raise MemoryError()
        # For Normalizing
        cdef double Sample_Min = 999999, Sample_Max = -999999
        with nogil:
            while (1):
                if not self.playing_sample:
                    break
                self.rep_time+=1
                if self.rep_limit!=0 and self.rep_time >= self.rep_limit:
                    self    .rep_time=0
                    self.ResetSample(1)
                # frequency envelopes / arpeggios
                self.arp_time+=1
                if self.arp_limit!=0 and self.arp_time>=self.arp_limit:
                    self.arp_limit=0
                    self.fperiod*=self.arp_mod
                self.fslide+=self.fdslide
                self.fperiod*=self.fslide
                if self.fperiod>self.fmaxperiod:
                    self.fperiod=self.fmaxperiod
                    if self.p_freq_limit>0:
                        self.playing_sample=False
                        break
                self.rfperiod=self.fperiod
                if self.vib_amp>0:
                    self.vib_phase+=self.vib_speed
                    self.rfperiod=self.fperiod*(1.0+sin(self.vib_phase)*self.vib_amp)
                self.period=<int>self.rfperiod
                if self.period<8: self.period=8
                self.square_duty+=self.square_slide
                if self.square_duty<0: self.square_duty=0
                if self.square_duty>0.5: self.square_duty=0.5
                # volume envelope
                self.env_time+=1
                if self.env_time>self.SFX_env_length[self.env_stage]:
                    self.env_time=0
                    self.env_stage+=1
                    if self.env_stage==3:
                        self.playing_sample=False
                        break
                # There was a select, PB's version of switch case here, but I don't think cython gives us switch case directly. Let it optimize to it.
                # Division by 0 here throws an exception, but in PureBasic it actually works, and causes clipping.
                if self.SFX_env_length[self.env_stage]==0: dirty=1
                if self.env_stage==0:
                    self.env_vol=INFINITY if self.SFX_env_length[0]==0 else (self.env_time / self.SFX_env_length[0])
                elif self.env_stage==1:
                    self.env_vol=1.0+(pow(1.0-(INFINITY if self.SFX_env_length[1]==0 else self.env_time / self.SFX_env_length[1]), 1.0)*2.0*self.p_env_punch)
                elif self.env_stage==2:
                    self.env_vol=1.0-(INFINITY if self.SFX_env_length[2]==0 else self.env_time / self.SFX_env_length[2])
                # phaser step
                self.fphase+=self.fdphase
                self.iphase=abs(<int>self.fphase)
                if self.iphase>1023: self.iphase=1023
                if self.flthp_d!=0:
                    self.flthp*=self.flthp_d
                    if self.flthp<0.00001: self.flthp=0.00001
                    if self.flthp>0.1: self.flthp=0.1
                si=0
                for si in range(self.SuperSample+1):
                    self.phase+=1
                    if self.phase>=self.period:
                        self.phase%=self.period
                        if self.wave_type>=3 and self.wave_type<=5:
                            i=0
                            for i in range(32):
                                self.SFX_noise_buffer[i]=Rnd(2.0)-1.0
                    # base waveform
                    fp=self.phase/self.period
                    if self.wave_type==0: # square
                        if fp<self.square_duty:
                            sample=0.5
                        else:
                            sample=-0.5
                    elif self.wave_type==1: # sawtooth
                        sample=1.0-fp*2.0
                    elif self.wave_type==2: # sine
                        sample=sin(fp*2.0*PI)
                    elif self.wave_type==3: # noise
                        sample=self.SFX_noise_buffer[<int>(self.phase*32 / self.period)]
                    elif self.wave_type==4: # pink noise (from JFXR)
                        curfp=self.phase*32/self.period
                        prevRandom=curRandom
                        ntemp=self.SFX_noise_buffer[<int>curfp]
                        self.SFX_pink_noise_buffer[0] = 0.99886 * self.SFX_pink_noise_buffer[0] + ntemp * 0.0555179
                        self.SFX_pink_noise_buffer[1] = 0.99332 * self.SFX_pink_noise_buffer[1] + ntemp * 0.0750759
                        self.SFX_pink_noise_buffer[2] = 0.96900 * self.SFX_pink_noise_buffer[2] + ntemp * 0.1538520
                        self.SFX_pink_noise_buffer[3] = 0.86650 * self.SFX_pink_noise_buffer[3] + ntemp * 0.3104856
                        self.SFX_pink_noise_buffer[4] = 0.55000 * self.SFX_pink_noise_buffer[4] + ntemp * 0.5329522
                        self.SFX_pink_noise_buffer[5] = -0.7616 * self.SFX_pink_noise_buffer[5] + ntemp * 0.0168980
                        curRandom = (self.SFX_pink_noise_buffer[0] + self.SFX_pink_noise_buffer[1] + self.SFX_pink_noise_buffer[2] + self.SFX_pink_noise_buffer[3] + self.SFX_pink_noise_buffer[4] + self.SFX_pink_noise_buffer[5] + self.SFX_pink_noise_buffer[6] + ntemp * 0.5362) / 7
                        self.SFX_pink_noise_buffer[6] = ntemp * 0.115926
                        prevfp=curfp
                        sample=curRandom
                    elif self.wave_type==5: # brown noise
                        curfp=self.phase*32/self.period
                        prevRandom=curRandom
                        ntemp=0.01*self.SFX_noise_buffer[<int>curfp]
                        if curRandom+ntemp<-1.0 or curRandom+ntemp>1.0: ntemp=-ntemp
                        curRandom+=ntemp
                        prevfp=curfp
                        sample=curRandom
                    elif self.wave_type==6: # triangle
                        if fp<=0.25: sample=4*fp
                        elif fp<=0.75: sample=2-4*fp
                        else: sample=-4+4*fp
                    elif self.wave_type==7: # breaker
                        ntemp=(fp+sqrt(0.75))%1
                        sample=-1.0+2*fabs(1-ntemp*ntemp*2)
                    elif self.wave_type==8: # absolute sine
                        sample=fabs(sin(fp*PI))
                    # lp filter
                    pp=self.fltp
                    self.fltw*=self.fltw_d
                    if self.fltw<0.0: self.fltw=0.0
                    if self.fltw>0.1: self.fltw=0.1
                    if self.p_lpf_freq!=1.0:
                        self.fltdp+=((sample-self.fltp)*self.fltw)
                        self.fltdp-=(self.fltdp*self.fltdmp)
                    else:
                        self.fltp=sample
                        self.fltdp=0.0
                    self.fltp+=self.fltdp
                    # hp filter
                    self.fltphp+=(self.fltp-pp)
                    self.fltphp-=(self.fltphp*self.flthp)
                    sample=self.fltphp
                    # phaser
                    self.SFX_phaser_buffer[self.ipp&1023]=sample
                    sample+=self.SFX_phaser_buffer[(self.ipp-self.iphase+1024)&1023]
                    self.ipp=(self.ipp+1)&1023
                    # final accumulation and envelope application
                    ssample += sample * self.env_vol
                ssample/=(self.SuperSample+1)
                Temp[SLength]=ssample
                if dirty==0 and not isinf(Temp[SLength]):
                    if Temp[SLength] > Sample_Max: Sample_Max = Temp[SLength]
                    if Temp[SLength] < Sample_Min: Sample_Min = Temp[SLength]
                SLength+=1
                Alength+=2
                dirty=0
            # whatever this loop does
            while (fabs(Temp[SLength])<=0.001 and SLength>1024):
                SLength-=1
                Alength-=2
            # normalize and store final sample data
            Sample_Div = fabs(Sample_Max)
            if fabs(Sample_Min) > Sample_Div: Sample_Div = fabs(Sample_Min)
        wf=io.BytesIO()
        # Now let's make a wave file to return
        wfw=wave.open(wf,'wb')
        wfw.setnchannels(1)
        wfw.setsampwidth(2)
        wfw.setframerate(Sample_Rate)
        # I can't think of a way to be more efficient about this. This is probably really slow.
        for MyLoop in range(SLength):
            wfw.writeframesraw(pcm16.pack(<short>(Temp[MyLoop]/Sample_Div*32000)))
        PyMem_Free(Temp)
        wfw.close()
        ret=wf.getvalue()
        wf.close()
        return ret
    
    # Overwriting this here because only SFXRWave stores filter_on, but GenBits should have ResetParams. Also should reset the internal variables used for making the data.
    cpdef ResetParams(self):
        self.ResetSample(False)
        self.filter_on=0
        GenBits.ResetParams(self)
