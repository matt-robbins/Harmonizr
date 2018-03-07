/*
	<samplecode>
		<abstract>
			A DSPKernel subclass implementing the realtime signal processing portion of the FilterDemo audio unit.
		</abstract>
	</samplecode>
*/

#ifndef FilterDSPKernel_hpp
#define FilterDSPKernel_hpp

#import "DSPKernel.hpp"
#import "ParameterRamper.hpp"
#import <vector>
#import <cmath>
#import <sys/time.h>
#include <Accelerate/Accelerate.h>
#include <dispatch/dispatch.h>

template <typename T> int sgn(T val) {
    return (T(0) < val) - (val < T(0));
}

typedef struct grain_s
{
    float size;
    float start;
    float ix;
    float ratio;
    float gain;
    float pan;
    int vix;
} grain_t;

typedef struct voice_s
{
    float error;
    float ratio;
    float target_ratio;
    float formant_ratio;
    float nextgrain;
    float pan;
    float ix1;
    float ix2;
    int xfade_ix;
    int xfade_dur;
    int midinote;
    int midivel;
    int lastnote;
    unsigned int sample_num;
} voice_t;

typedef struct triad_ratio_s
{
    float r1;
    float r2;
} triad_ratio_t;

typedef float chord_ratio_t[4];

typedef enum triads
{
    TRIAD_MAJOR_R = 0,
    TRIAD_MAJOR_1,
    TRIAD_MAJOR_2,
    TRIAD_MINOR_R,
    TRIAD_MINOR_1,
    TRIAD_MINOR_2,
    TRIAD_DIM_R,
    TRIAD_DIM_1,
    TRIAD_DIM_2,
    TRIAD_SUS4_R,
    TRIAD_SUS4_1,
    TRIAD_SUS4_2,
    TRIAD_SUS2_R,
    TRIAD_SUS2_1,
    TRIAD_SUS2_2,
    TRIAD_AUG,
    TRIAD_5TH,
    TRIAD_OCT
} triad_t;

enum {
    HarmParamKeycenter = 0,
    HarmParamInversion = 1,
    HarmParamNvoices = 2,
    HarmParamAuto = 3,
    HarmParamMidi = 4,
    HarmParamTriad = 5,
    HarmParamBypass = 6,
    HarmParamDouble = 7,
    HarmParamHgain = 8,
    HarmParamVgain = 9,
    HarmParamSpeed = 10,
    HarmParamInterval = 11
};

static inline double squared(double x) {
    return x * x;
}

/*
	FilterDSPKernel
	Performs our filter signal processing.
	As a non-ObjC class, this is safe to use from render thread.
*/
class FilterDSPKernel : public DSPKernel {
public:
    int n_channels = 0;
    // MARK: Member Functions

    FilterDSPKernel() {}
	
	void init(int channelCount, double inSampleRate) {
		n_channels = channelCount;
        fprintf(stderr,"**** init with %d channels! at %f Hz\n", n_channels, inSampleRate);
		
		sampleRate = float(inSampleRate);
        
        fft_s = vDSP_create_fftsetup(11, 2);
        
        fft_in.realp = (float *) calloc(2048, sizeof(float));
        fft_in.imagp = (float *) calloc(2048, sizeof(float));
        
        fft_out.realp = (float *) calloc(2048, sizeof(float));
        fft_out.imagp = (float *) calloc(2048, sizeof(float));
        
        fft_out2.realp = (float *) calloc(2048, sizeof(float));
        fft_out2.imagp = (float *) calloc(2048, sizeof(float));
        
        fft_buf.realp = (float *) calloc(2048, sizeof(float));
        fft_buf.imagp = (float *) calloc(2048, sizeof(float));
        
        ncbuf = 4096;
        cbuf = (float *) calloc(ncbuf + 3, sizeof(float));
        
        nvoices = 16;
        voices = (voice_t *) calloc(nvoices, sizeof(voice_t));
        voice_ix = 1;
        
        for (int k = 0; k < nvoices; k++)
        {
            voices[k].midinote = -1;
            voices[k].error = 0;
            voices[k].ratio = 1;
            voices[k].target_ratio = 1.0;
            voices[k].formant_ratio = 1;
            voices[k].nextgrain = 250;
            voices[k].ix1 = 0;
            voices[k].ix2 = 0;
            voices[k].xfade_ix = 0;
            voices[k].xfade_dur = 0;
            
            if (k >= 3)
            {
                voices[k].pan = ((float)(k - 3) / (float)(nvoices - 3)) - 0.5;
                //voices[k].formant_ratio = ((float)(k - 3) / (float)(nvoices - 3)) + 0.5;
            }
        }
        
        voices[1].formant_ratio = 0.99;
        voices[2].formant_ratio = 1.01;
        
        voices[0].midinote = 0;
        
        ngrains = 12 * nvoices;
        grains = new grain_t[ngrains];
        
        for (int k = 0; k < ngrains; k++)
        {
            grains[k].size = -1;
            grains[k].start = -1;
            grains[k].ix = 0;
            grains[k].gain = 1;
        }
        
        memset(Tbuf, 0, 5*sizeof(float));
        Tix = 0;
        
        // create grain window with zero-padded shoulders
        grain_window = new float[graintablesize + 6];
        memset(grain_window, 0, (graintablesize + 6) * sizeof(float));
        
        for (int k = 0; k < graintablesize; k++)
        {
            grain_window [3 + k] = 0.5 * (1 - cosf (2 * M_PI * k / graintablesize));
        }
        
        // define equal tempered interval ratios
        
        intervals = interval_table + 24;
        
        for (int k = -23; k < 24; k++)
        {
            intervals[k] = powf(2.0, (float) (k) / 12);
        }
        
        // define triad ratios
        
        triads[TRIAD_MAJOR_R].r1 = intervals[4];
        triads[TRIAD_MAJOR_R].r2 = intervals[7];
        triads[TRIAD_MAJOR_1].r1 = intervals[5];
        triads[TRIAD_MAJOR_1].r2 = intervals[9];
        triads[TRIAD_MAJOR_2].r1 = intervals[3];
        triads[TRIAD_MAJOR_2].r2 = intervals[8];
        
        triads[TRIAD_MINOR_R].r1 = intervals[3];
        triads[TRIAD_MINOR_R].r2 = intervals[7];
        triads[TRIAD_MINOR_1].r1 = intervals[5];
        triads[TRIAD_MINOR_1].r2 = intervals[8];
        triads[TRIAD_MINOR_2].r1 = intervals[4];
        triads[TRIAD_MINOR_2].r2 = intervals[9];
        
        triads[TRIAD_DIM_R].r1 = intervals[3];
        triads[TRIAD_DIM_R].r2 = intervals[6];
        triads[TRIAD_DIM_1].r1 = intervals[6];
        triads[TRIAD_DIM_1].r2 = intervals[9];
        triads[TRIAD_DIM_2].r1 = intervals[3];
        triads[TRIAD_DIM_2].r2 = intervals[9];
        
        triads[TRIAD_SUS4_R].r1 = intervals[5];
        triads[TRIAD_SUS4_R].r2 = intervals[7];
        triads[TRIAD_SUS4_1].r1 = intervals[2];
        triads[TRIAD_SUS4_1].r2 = intervals[7];
        triads[TRIAD_SUS4_2].r1 = intervals[5];
        triads[TRIAD_SUS4_2].r2 = intervals[10];
        
        triads[TRIAD_SUS2_R].r1 = intervals[2];
        triads[TRIAD_SUS2_R].r2 = intervals[7];
        
        triads[TRIAD_SUS2_1].r1 = intervals[5];
        triads[TRIAD_SUS2_1].r2 = intervals[10];
        
        triads[TRIAD_SUS2_2].r1 = intervals[5];
        triads[TRIAD_SUS2_2].r2 = intervals[7];
        
        triads[TRIAD_AUG].r1 = intervals[4];
        triads[TRIAD_AUG].r2 = intervals[8];
        
        triads[TRIAD_5TH].r1 = 3.0/2.0;
        triads[TRIAD_5TH].r2 = 2.0;
        
        triads[TRIAD_OCT].r1 = 0.5;
        triads[TRIAD_OCT].r2 = 2.0;
        
        memset(midinotes, 0, 128 * sizeof(int));
        
	}
    
    void fini() {
        vDSP_destroy_fftsetup(fft_s);
        delete grain_window;
        delete grains;
        free(fft_in.realp);
        free(fft_in.imagp);
        free(fft_out.realp);
        free(fft_out.imagp);
        free(fft_out2.realp);
        free(fft_out2.imagp);
        free(fft_buf.realp);
        free(fft_buf.imagp);
        free(cbuf);
        free(voices);
    }
	
	void reset() {
        for (int k = 0; k < nvoices; k++)
        {
            voices[k].midinote = -1;
            voices[k].error = 0;
            voices[k].ratio = 1;
            voices[k].target_ratio = 1.0;
            voices[k].formant_ratio = 1;
            voices[k].nextgrain = 250;
            
            if (k >= 3)
            {
                voices[k].pan = ((float)(k - 3) / (float)(nvoices - 3)) - 0.5;
                //voices[k].formant_ratio = ((float)(k - 3) / (float)(nvoices - 3)) + 0.5;
            }
        }
        voice_ix = 1;
        
        cix = 0;
        rix = 0;
        rcnt = 256;
        T = 400;
        
        pitchmark[0] = 0;
        pitchmark[1] = -1;
        pitchmark[2] = -1;
	}
    
    float cubic (float *v, float a)
    {
        float b, c;
        
        b = 1 - a;
        c = a * b;
        return (1.0f + 1.5f * c) * (v[1] * b + v[2] * a)
        - 0.5f * c * (v[0] * b + v[1] + v[2] + v[3] * a);
    }
    
    float linear (float *v, float a)
    {
        return v[0] * (1 - a) + v[1] * a;
    }
	
	void setParameter(AUParameterAddress address, AUValue value) {
        switch (address) {
            case HarmParamKeycenter:
                root_key = (int) clamp(value,0.f,47.f);
                break;
            case HarmParamInversion:
                inversion = (int) clamp(value,0.f,3.f);
                break;
            case HarmParamNvoices:
                n_auto = (int) clamp(value,1.f,4.f);
                fprintf(stderr, "nvoices: %d\n", n_auto);
                break;
            case HarmParamAuto:
                autotune = (int) clamp(value,0.f,1.f);
                fprintf(stderr, "autotune: %d\n", autotune);
                break;
            case HarmParamMidi:
                midi_enable = (int) clamp(value,0.f,1.f);
                break;
            case HarmParamTriad:
                triad = (int) clamp(value,-1.f,30.f);
                break;
            case HarmParamBypass:
                bypass = (int) clamp(value,0.f,1.f);
                printf("set bypass to %d\n", bypass);
                break;
            case HarmParamHgain:
                harmgain_target = clamp(value, 0.f, 2.f);
                break;
            case HarmParamVgain:
                voicegain = clamp(value, 0.f, 2.f);
                break;
            case HarmParamSpeed:
                speed = clamp(value, 0.f, 1.f);
                break;
            case HarmParamInterval:
            default:
                int addr = (int) address - (int) HarmParamInterval;
                int scale_degree = addr / 4;
                
                chord_ratio_t * table = major_chord_table;
                if (scale_degree > 11)
                    table = minor_chord_table;
                if (scale_degree > 23)
                    table = blues_chord_table;
                
                float * ratios = (float *) &table[scale_degree%12];
                
                ratios[addr & 0x3] = intervals[(int) value];
                
                break;
        }
	}

	AUValue getParameter(AUParameterAddress address) {
        switch (address) {
            case HarmParamKeycenter:
                return (float) root_key;
            case HarmParamInversion:
                return (float) inversion;
            case HarmParamNvoices:
                return (float) n_auto;
            case HarmParamAuto:
                return (float) autotune;
            case HarmParamMidi:
                return (float) midi_enable;
            case HarmParamTriad:
                return (float) triad;
            case HarmParamBypass:
                return (float) bypass;
            case HarmParamHgain:
                return harmgain;
            case HarmParamVgain:
                return voicegain;
            case HarmParamSpeed:
                return speed;
				
            case HarmParamInterval:
            default:
                int addr = (int) address - (int) HarmParamInterval;
                int scale_degree = addr / 4;
                
                chord_ratio_t * table = major_chord_table;
                if (scale_degree > 11)
                    table = minor_chord_table;
                if (scale_degree > 23)
                    table = blues_chord_table;
                
                float * ratios = (float *) &table[scale_degree%12];
                return round(log2(ratios[addr & 0x3])*12);
        }
	}

	void startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) override {
        return;
	}
	
	void setBuffers(AudioBufferList* inBufferList, AudioBufferList* outBufferList) {
		inBufferListPtr = inBufferList;
		outBufferListPtr = outBufferList;
	}
    
    virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) override {
        if (midiEvent.length != 3) return;
        uint8_t status = midiEvent.data[0] & 0xF0;
        uint8_t channel = midiEvent.data[0] & 0x0F; // works in omni mode.
        if (channel != 0)
            return;
        
        switch (status) {
            case 0x80 : { // note off
                uint8_t note = midiEvent.data[1];
                if (note > 127) break;
                remnote((int)note);
                break;
            }
            case 0x90 : { // note on
                uint8_t note = midiEvent.data[1];
                uint8_t veloc = midiEvent.data[2];
                if (note > 127 || veloc > 127) break;
                if (veloc == 0)
                    remnote((int)note);
                else
                    addnote((int)note,(int)veloc);
                break;
            }
            case 0xB0 : { // control
                uint8_t num = midiEvent.data[1];
                uint8_t val = midiEvent.data[2];
                if (num == 11)
                {
                    midigain = (float) val / 127.0;
                }
                if (num == 123) { // all notes off

                }
                break;
            }
        }
    }
	
	void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
		int channelCount = n_channels;
        sample_count += frameCount;
        //fprintf(stderr, "in = 0x%p, val = %f\n", inBufferListPtr->mBuffers[0].mData, *(float*)inBufferListPtr->mBuffers[0].mData);
        //fprintf(stderr, "rendering! frameCount = %d, channelCount = %d\n", frameCount, n_channels);
        // For each sample.
		for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex)
        {
            int frameOffset = int(frameIndex + bufferOffset);
			
            int channel = 0;
			
            float* in  = (float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
            float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
            float* out2 = out;
            
            if (channelCount > 1)
            {
                out2 = (float*)outBufferListPtr->mBuffers[1].mData + frameOffset;
            }

            cbuf[cix] = *in;
            
            if (bypass)
            {
                *out = *in / 2;
                *out2 = *out;
                continue;
            }
            else
            {
                *out = *out2 = 0;
            }
            
            if (cix < 3)
            {
                cbuf[ncbuf+cix] = cbuf[cix];
            }
            if (++cix >= ncbuf)
                cix = 0;
            
            if (--rcnt == 0)
            {
                rcnt = 256;
                int oldT = T;
                float p = estimate_pitch(cix - 2*maxT);
                if (p > 0)
                    T = p;
                else
                    T = oldT;
                
                voiced = (p != 0);
            }
            
            float dp = cix - 2*maxT - pitchmark[0];
            if (dp < 0)
                dp += ncbuf;
            
            if (dp > (T + T/4))
            {
                findmark();
                update_voices();
                
                //printf("pitchmark[0,1,2] = %.2f,%.2f,%.2f\ninput = %d\n", pitchmark[0],pitchmark[1],pitchmark[2],cix);
            }
            
            if (pitchmark[2] < 0)
                continue;
            
            // voice 0 uses simple cubic resampling instead of PSOLA (if pitch correction is used)
            
            int first_psola_voice = 0;
            
            if (!autotune)
            {
                first_psola_voice = 1;
                
                int dx1 = cix - (int) voices[0].ix1;
                if (dx1 < 0) dx1 += ncbuf;

                if (dx1 > 512 + (int) T)
                {
                    voices[0].ix1 += T;
                }

                if (dx1 < 512 - (int) T)
                {
                    voices[0].ix1 -= T;
                }

                voices[0].ix1 += voices[0].ratio;

                if (voices[0].ix1 >= ncbuf)
                    voices[0].ix1 -= ncbuf;
                if (voices[0].ix1 < 0)
                    voices[0].ix1 += ncbuf;

                int ix1i = (int) voices[0].ix1;
                *out = voicegain * cubic(cbuf + ix1i, voices[0].ix1 - ix1i) / 2;

                *out2 = *out;
            }
            
            // Ramp Gain
            
            harmgain += .001 * sgn(harmgain_target - harmgain);
    
            for (int vix = first_psola_voice; vix < nvoices; vix++)
            {
                if (voices[vix].midinote == -1 || (vix > n_auto && !midi_enable))
                    continue;
                
                float unvoiced_offset = 0;
                if (!voiced && vix > 0)
                {
                    continue;
                    //unvoiced_offset = T * (0.5 - (float) rand() / RAND_MAX);
                }
                
                float midigain_local = 1.0;
                if (vix >= 3)
                    midigain_local = midigain;
                
                if (--voices[vix].nextgrain < 0)
                {
                    // search for the first open grain
                    
                    for (int k = 0; k < ngrains; k++)
                    {
                        if (grains[k].size < 0)
                        {
                            grains[k].size = 2 * T;
                            grains[k].start = pitchmark[0] - voices[vix].nextgrain - T + unvoiced_offset;
                            grains[k].ratio = voices[vix].formant_ratio;
                            
                            grains[k].ix = 0;
                            grains[k].gain = midigain_local * (float) voices[vix].midivel / 127.0;
                            grains[k].pan = voices[vix].pan;
                            grains[k].vix = vix;
                            
                            if (vix == 0)
                            {
                                grains[k].gain = 1.0;
                            }
                            
                            if (!voiced)
                            {
                                grains[k].ratio = voices[vix].ratio;
                            }
                            else
                            {
                                // for low transpositions, increase gain
                                if (voices[vix].ratio < 1)
                                    grains[k].gain *= powf(1/voices[vix].ratio,0.5);
                                
                                // for high transpositions, start shortening the blips.
                                if (voices[vix].ratio > 1.7)
                                {
                                    grains[k].ratio *= (1 + (voices[vix].ratio - 1.7)/2);
                                    //grains[k].gain *= powf(voices[vix].ratio,0.5);
                                }
                            }
                            
                            voices[vix].nextgrain += (T / voices[vix].ratio);
                            
                            //printf("maxgrain = %d\n", maxgrain);
                            if (k > maxgrain)
                                maxgrain = k;
                            
                            break;
                        }
                    }
                    for (int k = maxgrain; k > 0; k--)
                    {
                        if (grains[k].size >= 0)
                            break;
                        
                        maxgrain = k;
                    }
                }
            }
            
            for (int ix = 0; ix <= maxgrain; ix++)
            {
                grain_t g = grains[ix];
                
                // if this grain has been "triggered", it's size is > 0
                if (g.size > 0)
                {
                    float fi = g.start + g.ix;
                    
                    if (fi >= ncbuf)
                        fi -= ncbuf;
                    else if (fi < 0)
                        fi += ncbuf;
                    
                    int i = (int) fi;
                    //float u = cbuf[i];
                    float u = cubic (cbuf + i, fi - i);
                    
                    float wi = 2 + graintablesize * (g.ix / g.size);
                    i = (int) wi;
                    float w = cubic (grain_window + i, wi - i);
                    
                    float hgain = g.vix ? harmgain : 1.0;
                    
                    *out += u * hgain * w * g.gain * (g.pan + 1.0)/2;
                    *out2 += u * hgain * w * g.gain * (-g.pan + 1)/2;
                    
                    g.ix += g.ratio;
                    
                    if (g.ix > g.size)
                    {
                        g.size = -1;
                        //printf("ending grain %d\n", ix);
                    }
                    
                    grains[ix] = g;
                }
            }
            
		}
	}
    
    float estimate_pitch(int start_ix)
    {
        memset(fft_in.realp, 0, nfft * sizeof(float));
        memset(fft_in.imagp, 0, nfft * sizeof(float));
        
        for (int k = 0; k < maxT; k++)
        {
            int ix = (start_ix + k) & cmask;
            fft_in.realp[k] = cbuf[ix];
        }
        
        vDSP_fft_zopt(fft_s, &fft_in, 1, &fft_out, 1, &fft_buf, 11, 1);
        
        for (int k = maxT; k < 2*maxT; k++)
        {
            int ix = (start_ix + k) & cmask;
            fft_in.realp[k] = cbuf[ix];
        }
        vDSP_fft_zopt(fft_s, &fft_in, 1, &fft_out2, 1, &fft_buf, 11, 1);
        
        // conjugate small window and correlate with large window
        for (int k = 0; k < nfft; k++)
        {
            float r1,c1,r2,c2;
            r1 = fft_out.realp[k]; c1 = -fft_out.imagp[k];
            r2 = fft_out2.realp[k]; c2 = fft_out2.imagp[k];

            fft_in.realp[k] = r1*r2 - c1*c2;
            fft_in.imagp[k] = r1*c2 + r2*c1;
        }
        // inverse transform
        vDSP_fft_zopt(fft_s, &fft_in, 1, &fft_out, 1, &fft_buf, 11, -1);
        
        float sumsq_ = fft_out.realp[0]/nfft;
        float sumsq = sumsq_;
        
        float df,cmdf,cmdf1,cmdf2, sum = 0;
        
        float period = 0.0;
        
        cmdf2 = cmdf1 = cmdf = 1;
        for (int k = 1; k < maxT; k++)
        {
            int ix1 = (start_ix + k) & cmask;
            int ix2 = (start_ix + k + maxT) & cmask;
            
            sumsq -= cbuf[ix1]*cbuf[ix1];
            sumsq += cbuf[ix2]*cbuf[ix2];
            
            df = sumsq + sumsq_ - 2 * fft_out.realp[k]/nfft;
            sum += df;
            cmdf2 = cmdf1; cmdf1 = cmdf;
            cmdf = (df * k) / sum;
            
            if (k > 0 && cmdf2 > cmdf1 && cmdf1 < cmdf && cmdf1 < 0.2 && k > 20)
            {
                period = (float) (k-1) + 0.5*(cmdf2 - cmdf)/(cmdf2 + cmdf - 2*cmdf1); break;
            }
        }
        
        Tbuf[Tix++] = period;
        
        if (Tix >= nmed)
            Tix = 0;
        
        memcpy(Tsrt, Tbuf, nmed * sizeof(float));
        vDSP_vsort(Tsrt, (vDSP_Length) nmed, 1);
        
        return Tsrt[nmed/2];
    }
    
    void findmark (void)
    {
        int mask = ncbuf - 1;
        
        memmove(pitchmark + 1, pitchmark, 2 * sizeof(float));
        pitchmark[0] = pitchmark[1] + T;
        
        if (pitchmark[0] >= ncbuf - 1)
            pitchmark[0] -= ncbuf;
        
        if (!voiced)
            return;
        
        // find center of mass around next pitch mark
        float mean = 0.0;
        float min = HUGE_VALF;
        
        int srch_n = (int)T/4;
        
        for (int k = -srch_n; k < srch_n; k++)
        {
            int ix = ((int) pitchmark[0] + k) & mask;
            if (cbuf[ix] < min)
                min = cbuf[ix];
        }
        
        mean = 0;
        float sum = 0;
        for (int k = -srch_n; k < srch_n; k++)
        {
            int ix = ((int) pitchmark[0] + k) & mask;
            mean += (float) k * (cbuf[ix] - min);
            sum += (cbuf[ix] - min);
        }
        
        if (sum == 0)
            pitchmark[0] += T;
        else
        {
            pitchmark[0] += (mean/sum);
        }
        
        if (pitchmark[0] < 0)
            pitchmark[0] += ncbuf;
        else if (pitchmark[0] > ncbuf - 1)
            pitchmark[0] -= ncbuf;
    }
    
    void addnote(int note, int vel)
    {
        int min_dist = 129;
        int dist;
        int min_ix = -1;
        midi_changed_sample_num = sample_count;
        midi_changed = 1;
        
        // look for one with the same note and take that if we can, or the empty one with
        // the closest last note to the one we want
        for (int k = 3; k < nvoices; k++)
        {
            dist = abs(voices[k].lastnote - note);
            if ((dist < min_dist && voices[k].midinote < 0) || voices[k].midinote == note)
            {
                min_ix = k;
                min_dist = dist;
            }
        }
        
        if (min_dist >= 0)
        {
            voices[min_ix].lastnote = voices[min_ix].midinote;
            voices[min_ix].midinote = note;
            voices[min_ix].midivel = vel;
            voices[min_ix].sample_num = sample_count;
            //voices[min_ix].ratio = 1.0;
            voices[min_ix].nextgrain = 0;
            return;
        }
        
        // otherwise, we are stealing
        min_dist = 129;
        min_ix = -1;
        for (int k = 3; k < nvoices; k++)
        {
            dist = abs(voices[k].midinote - note);
            if (dist < min_dist)
            {
                min_dist = dist;
                min_ix = k;
            }
        }
        
        voices[min_ix].lastnote = voices[min_ix].midinote;
        voices[min_ix].midinote = note;
        voices[min_ix].midivel = vel;
        voices[min_ix].sample_num = sample_count;
        voices[min_ix].nextgrain = 0;
        
        if (++voice_ix > nvoices)
            voice_ix = 3;
        
        return;
    }
    
    void remnote(int note)
    {
        for (int k = 3; k < nvoices; k++)
        {
            if (voices[k].midinote == note)
            {
                voices[k].lastnote = note;
                voices[k].midinote = -1;
            }
        }
        
        midi_changed_sample_num = sample_count;
        midi_changed = 1;
    }
    
    void analyze_harmony(void)
    {
        //float intervals[127];
        int octave[12];
        
        memset(octave, 0, 12 * sizeof(int));
        
        int n = 0;
        for (int j = 3; j < nvoices; j++)
        {
            if (voices[j].midinote < 0)
                continue;
            
            midinotes[n++] = (float) voices[j].midinote;
            
            octave[voices[j].midinote % 12] = 1;
        }
        if (n == 0)
            return;
        
        vDSP_vsort(midinotes, (vDSP_Length) n, 1);
        
        for (int j = 0; j < n; j++)
        {
            // ignore doubles
            int dbl = 0;
            for (int k = 0; k < j; k++)
            {
                if (((int)(midinotes[j] - midinotes[k]) % 12) == 0)
                {
                    dbl = 1; break;
                }
            }
            
            if (dbl)
                continue;
            
            int ix = (int) midinotes[j] % 12;
            
            if (octave[(ix+2)%12] && octave[(ix+6)%12])
            {
                // 7th
            }
            
            if (octave[(ix+3)%12] && octave[(ix+6)%12])
            {
                // dim
            }
            
            if (octave[(ix+3)%12] && octave[(ix+7)%12])
            {
                //min
                root_key = ix + 12;
                break;
            }
            
            if (octave[(ix+4)%12] && octave[(ix+7)%12])
            {
                //maj
                root_key = ix;
                break;
            }
            
            if (octave[(ix+4)%12] && octave[(ix+8)%12])
            {
                //aug
            }
       
        }
        
        //dispatch_semaphore_signal(sem);
    }
    
    void update_voices (void)
    {
        voices[0].error = 0;
        //voices[0].ratio = 1;
        voices[0].target_ratio = 1;
        voices[0].formant_ratio = 1.0;
        voices[0].midivel = 127;
        voices[0].midinote = 0;
        
        voices[1].midinote = -1;
        voices[1].midivel = 65;
        voices[1].pan = 0.5;
        
        voices[2].midinote = -1;
        voices[2].midivel = 65;
        voices[2].pan = -0.5;
        
        voices[3].midinote = -1;
        voices[3].midivel = 65;
        voices[3].pan = -0.5;
        
        if (midi_changed && (sample_count - midi_changed_sample_num) > (int) sampleRate / 50)
        {
            midi_changed = 0;
            //printf("%d samples since last midi note\n", sample_count - midi_changed_sample_num);
            analyze_harmony();
        }
        
        if (!voiced)
        {
            note_number = -1.0;
            return;
        }
        
        //int n_auto = 4;
            
        float f = log2f (sampleRate / (T * 440));
        
        float note_f = f * 12.0;
        int nn = (int) round(note_f);
        float error = (note_f - (float)nn)/12;
        float error_ratio = powf(2.0, error);
        
        int root = root_key % 12;
        int quality = root_key / 12;
        
        int interval = (nn + 69 - root) % 12;
        note_number = (nn + 69) % 12 + (note_f - nn);
        
//        if (autotune)
//        {
//            // lock to nearest note
//            voices[0].target_ratio = 1.0/error_ratio;
//        }
        
        int start = autotune ? 0 : 1;

        if (triad >= 0)
        {
            voices[0].midinote = 0;
            voices[1].midinote = 0;
            voices[2].midinote = 0;
            voices[1].target_ratio = voices[1].ratio = triads[triad].r1;
            voices[2].target_ratio = voices[2].ratio = triads[triad].r2;
        }
        
        else if (auto_enable)
        {
            for (int k = start; k < n_auto; k++)
            {
                voices[k].midinote = 0;
                
                if (quality == 0)
                {
                    voices[k].target_ratio = major_chord_table[interval][k];
                }
                else if (quality == 1)
                {
                    voices[k].target_ratio = minor_chord_table[interval][k];
                }
                else if (quality == 2)
                {
                    voices[k].target_ratio = blues_chord_table[interval][k];
                }
                
                if (k > inversion)
                    voices[k].target_ratio *= 0.5;
            }
        }
        else
        {
            for (int k = 0; k < n_auto; k++)
            {
                voices[k].ratio = voices[k].target_ratio = 1.0;
            }
        }
        
        for (int k = n_auto; k < nvoices; k++)
        {
            if (voices[k].midinote < 0)
                continue;
            
            //voices[0].midinote = 0;
            
            float error_hsteps = (voices[k].midinote - 69) - note_f;
            
            voices[k].target_ratio = powf(2.0, error_hsteps/12);
            //voices[k].ratio = voices[k].target_ratio;
        }
    
        for (int k = 0; k < nvoices; k++)
        {
            if (k < n_auto && k >= start)
                voices[k].target_ratio /= error_ratio; // for autoharm
            
            voices[k].ratio = 0.8 * voices[k].ratio + 0.2 * voices[k].target_ratio;
        }
    }
	
    // MARK: Member Variables

private:
	//std::vector<FilterState> channelStates;
    int nfft = 2048;
    int l2nfft = 11;
    DSPSplitComplex fft_in, fft_out, fft_out2, fft_buf;
    float * cbuf;
    int ncbuf = 4096;
    int cix = 0;
    int rix = 0;
    int maxgrain = 0;
    float rcnt = 256;
    float T = 400;
    int nmed = 3;
    float Tbuf[3];
    float Tsrt[3];
    int Tix;
    float pitchmark[3] = {0,-1,-1};
    int maxT = 600; // note nfft should be bigger than 3*maxT
    int cmask = ncbuf - 1;
    int voiced = 0;
    FFTSetup fft_s;
	float sampleRate = 44100.0;

    int keycenter = 0;
    float midinotes[128];
    float midigain = 1.0;
    float harmgain = 1.0;
    float harmgain_target = 1.0;
    float voicegain = 1.0;
    float speed = 1.0;
    int autotune = 1;
    int bypass = 0;
    
    int nvoices = 16;
    int voice_ix = 3;
    
    int chord_quality = 0;
    voice_t * voices;
    int inversion = 2;
    int midi_enable = 1;
    int auto_enable = 1;
    int n_auto = 4;
    int triad = -1;
    float interval_table[48];
    float * intervals;
    triad_ratio_t triads[18];
    chord_ratio_t major_chord_table[12];
    chord_ratio_t minor_chord_table[12];
    chord_ratio_t blues_chord_table[12];
    
    int ngrains;
    int grain_ix = 0;
    grain_t * grains;
    
    int graintablesize = maxT;
    float * grain_window;
    
    unsigned int sample_count = 0;
    unsigned int midi_changed_sample_num = 0;
    unsigned int midi_changed = 1;

	AudioBufferList* inBufferListPtr = nullptr;
	AudioBufferList* outBufferListPtr = nullptr;

public:

    float note_number;
    int root_key = 0;
    dispatch_semaphore_t sem;
};

#endif /* FilterDSPKernel_hpp */