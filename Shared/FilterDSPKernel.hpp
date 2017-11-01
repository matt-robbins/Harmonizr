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


typedef struct grain_s
{
    float size;
    float start;
    float ix;
    float ratio;
    float gain;
    float pan;
} grain_t;

typedef struct voice_s
{
    float error;
    float ratio;
    float target_ratio;
    float formant_ratio;
    float nextgrain;
    float pan;
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

static inline float convertBadValuesToZero(float x) {
	/*
		Eliminate denormals, not-a-numbers, and infinities.
		Denormals will fail the first test (absx > 1e-15), infinities will fail 
        the second test (absx < 1e15), and NaNs will fail both tests. Zero will
        also fail both tests, but since it will get set to zero that is OK.
	*/
		
	float absx = fabs(x);

    if (absx > 1e-15 && absx < 1e15) {
		return x;
	}

    return 0.0;
}


enum {
	FilterParamCutoff = 0,
	FilterParamResonance = 1,
    HarmParamKeycenter = 2,
    HarmParamInversion = 3,
    HarmParamAuto = 4,
    HarmParamMidi = 5,
    HarmParamTriad = 6
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
    // MARK: Types
	struct FilterState {
		float x1 = 0.0;
		float x2 = 0.0;
		float y1 = 0.0;
		float y2 = 0.0;
		
		void clear() {
			x1 = 0.0;
			x2 = 0.0;
			y1 = 0.0;
			y2 = 0.0;
		}

		void convertBadStateValuesToZero() {
			/*
				These filters work by feedback. If an infinity or NaN should come 
                into the filter input, the feedback variables can become infinity 
                or NaN which will cause the filter to stop operating. This function
                clears out any bad numbers in the feedback variables.
			*/
			x1 = convertBadValuesToZero(x1);
			x2 = convertBadValuesToZero(x2);
			y1 = convertBadValuesToZero(y1);
			y2 = convertBadValuesToZero(y2);
		}
	};
	
	struct BiquadCoefficients {
		float a1 = 0.0;
		float a2 = 0.0;
		float b0 = 0.0;
		float b1 = 0.0;
		float b2 = 0.0;

		void calculateLopassParams(double frequency, double resonance) {
			/*
                The transcendental function calls here could be replaced with
                interpolated table lookups or other approximations.
            */
            
            // Convert from decibels to linear.
			double r = pow(10.0, 0.05 * -resonance);
			
			double k  = 0.5 * r * sin(M_PI * frequency);
			double c1 = (1.0 - k) / (1.0 + k);
			double c2 = (1.0 + c1) * cos(M_PI * frequency);
			double c3 = (1.0 + c1 - c2) * 0.25;
			
			b0 = float(c3);
			b1 = float(2.0 * c3);
			b2 = float(c3);
			a1 = float(-c2);
			a2 = float(c1);
		}
		
        // Arguments in Hertz.
		double magnitudeForFrequency( double inFreq) {
			// Cast to Double.
			double _b0 = double(b0);
			double _b1 = double(b1);
			double _b2 = double(b2);
			double _a1 = double(a1);
			double _a2 = double(a2);
		
			// Frequency on unit circle in z-plane.
			double zReal      = cos(M_PI * inFreq);
			double zImaginary = sin(M_PI * inFreq);
			
			// Zeros response.
			double numeratorReal = (_b0 * (squared(zReal) - squared(zImaginary))) + (_b1 * zReal) + _b2;
			double numeratorImaginary = (2.0 * _b0 * zReal * zImaginary) + (_b1 * zImaginary);
			
			double numeratorMagnitude = sqrt(squared(numeratorReal) + squared(numeratorImaginary));
			
			// Poles response.
			double denominatorReal = squared(zReal) - squared(zImaginary) + (_a1 * zReal) + _a2;
			double denominatorImaginary = (2.0 * zReal * zImaginary) + (_a1 * zImaginary);
			
			double denominatorMagnitude = sqrt(squared(denominatorReal) + squared(denominatorImaginary));
			
			// Total response.
			double response = numeratorMagnitude / denominatorMagnitude;

			return response;
		}
	};
    
    // MARK: Member Functions

    FilterDSPKernel() {}
	
	void init(int channelCount, double inSampleRate) {
		channelStates.resize(channelCount);
		
		sampleRate = float(inSampleRate);
		nyquist = 0.5 * sampleRate;
		inverseNyquist = 1.0 / nyquist;
		dezipperRampDuration = (AUAudioFrameCount)floor(0.02 * sampleRate);
		cutoffRamper.init();
		resonanceRamper.init();
        
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
            
            if (k >= 3)
            {
                voices[k].pan = ((float)(k - 3) / (float)(nvoices - 3)) - 0.5;
                //voices[k].formant_ratio = ((float)(k - 3) / (float)(nvoices - 3)) + 0.5;
            }
        }
        
        voices[1].formant_ratio = 1.05;
        voices[2].formant_ratio = 1.1;
        
        voices[0].midinote = 0;
        
        ngrains = 16 * nvoices;
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
        for (int k = 0; k < 12; k++)
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
        
        // set up default chord tables
        major_chord_table[0] = triads[TRIAD_MAJOR_R];
        major_chord_table[1] = triads[TRIAD_DIM_R];
        major_chord_table[2] = triads[TRIAD_MINOR_R];
        major_chord_table[3] = triads[TRIAD_DIM_R];
        major_chord_table[4] = triads[TRIAD_MAJOR_2];
        major_chord_table[5] = triads[TRIAD_MAJOR_R];
        major_chord_table[6] = triads[TRIAD_DIM_R];
        major_chord_table[7] = triads[TRIAD_MAJOR_1];
        major_chord_table[8] = triads[TRIAD_AUG];
        major_chord_table[9] = triads[TRIAD_MINOR_R];
        major_chord_table[10] = triads[TRIAD_MAJOR_R];
        major_chord_table[11] = triads[TRIAD_DIM_R];

        minor_chord_table[0] = triads[TRIAD_MINOR_R];
        minor_chord_table[1] = triads[TRIAD_DIM_R];
        minor_chord_table[2] = triads[TRIAD_DIM_R];
        minor_chord_table[3] = triads[TRIAD_MINOR_2];
        minor_chord_table[4] = triads[TRIAD_DIM_R];
        minor_chord_table[5] = triads[TRIAD_DIM_2];
        minor_chord_table[6].r1 = intervals[6]; minor_chord_table[6].r2 = intervals[8];
        minor_chord_table[7] = triads[TRIAD_MINOR_1];
        minor_chord_table[8] = triads[TRIAD_MAJOR_R];
        minor_chord_table[9] = triads[TRIAD_DIM_R];
        minor_chord_table[10] = triads[TRIAD_MAJOR_R];
        minor_chord_table[11] = triads[TRIAD_DIM_R];

        blues_chord_table[0] = triads[TRIAD_MAJOR_R]; blues_chord_table[0].r2 = intervals[10];
        blues_chord_table[1] = triads[TRIAD_DIM_2];
        blues_chord_table[2].r1 = intervals[2]; blues_chord_table[2].r2 = intervals[8];
        blues_chord_table[3] = triads[TRIAD_MAJOR_R];
        blues_chord_table[4] = triads[TRIAD_DIM_R];
        blues_chord_table[5] = triads[TRIAD_MAJOR_R];
        blues_chord_table[6] = triads[TRIAD_MAJOR_R];
        blues_chord_table[7] = triads[TRIAD_MINOR_R]; blues_chord_table[7].r2 = intervals[5];
        blues_chord_table[8] = triads[TRIAD_MAJOR_R];
        blues_chord_table[9] = triads[TRIAD_MAJOR_R];
        blues_chord_table[10].r1 = intervals[2]; blues_chord_table[10].r2 = intervals[6];
        blues_chord_table[11] = triads[TRIAD_MAJOR_R];
        
        memset(midinotes, 0, 128 * sizeof(int));
        
	}
	
	void reset() {
		cutoffRamper.reset();
		resonanceRamper.reset();
		for (FilterState& state : channelStates) {
			state.clear();
		}
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
            case FilterParamCutoff:
                //cutoffRamper.setUIValue(clamp(value * inverseNyquist, 0.0f, 0.99f));
				cutoffRamper.setUIValue(clamp(value * inverseNyquist, 0.0005444f, 0.9070295f));
				break;
                
            case FilterParamResonance:
                resonanceRamper.setUIValue(clamp(value, -20.0f, 20.0f));
				break;
            case HarmParamKeycenter:
                root_key = (int) clamp(value,0.f,47.f);
                break;
            case HarmParamInversion:
                inversion = (int) clamp(value,0.f,2.f);
                printf("inversion = %d, %f\n", inversion, value);
                break;
            case HarmParamAuto:
                auto_enable = (int) clamp(value,0.f,1.f);
                printf("auto_enble = %d\n", auto_enable);
                break;
            case HarmParamMidi:
                midi_enable = (int) clamp(value,0.f,1.f);
                printf("midi_enble = %d\n", midi_enable);
                break;
            case HarmParamTriad:
                triad = (int) clamp(value,-1.f,30.f);
                printf("triad override = %d\n", triad);
                break;
        }
	}

	AUValue getParameter(AUParameterAddress address) {
        switch (address) {
            case FilterParamCutoff:
                // Return the goal. It is not thread safe to return the ramping value.
                //return (cutoffRamper.getUIValue() * nyquist);
                return roundf((cutoffRamper.getUIValue() * nyquist) * 100) / 100;

            case FilterParamResonance:
                return resonanceRamper.getUIValue();
                
            case HarmParamKeycenter:
                return (float) keycenter;
            case HarmParamInversion:
                return (float) inversion;
            case HarmParamAuto:
                return (float) auto_enable;
            case HarmParamMidi:
                return (float) midi_enable;
            case HarmParamTriad:
                return (float) triad;
				
			default: return 12.0f * inverseNyquist;
        }
	}

	void startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) override {
        switch (address) {
			case FilterParamCutoff:
				cutoffRamper.startRamp(clamp(value * inverseNyquist, 12.0f * inverseNyquist, 0.99f), duration);
				break;
			
			case FilterParamResonance:
				resonanceRamper.startRamp(clamp(value, -20.0f, 20.0f), duration);
				break;
		}
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
                if (num == 123) { // all notes off

                }
                break;
            }
        }
    }
	
	void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) override {
		int channelCount = int(channelStates.size());
        
        sample_count += frameCount;
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
            
            if (cix < 3)
            {
                cbuf[ncbuf+cix] = cbuf[cix];
            }
            if (++cix >= ncbuf)
                cix = 0;
            
            if (--rcnt == 0)
            {
                rcnt = 256;
                float p = estimate_pitch(cix - 2*maxT);
                if (p > 0)
                    T = p;
                else
                    T = 250;
                
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
            
            for (int vix = 0; vix < nvoices; vix++)
            {
                if (voices[vix].midinote == -1 || (vix > 2 && !midi_enable))
                    continue;
                
                float unvoiced_offset = 0;
                if (!voiced)
                {
                    unvoiced_offset = T * (0.5 - (float) rand() / RAND_MAX);
                }
                
                if (--voices[vix].nextgrain < 0)
                {
                    grains[grain_ix].size = 2 * T;
                    grains[grain_ix].start = pitchmark[1] - voices[vix].nextgrain - T + unvoiced_offset;
                    grains[grain_ix].ratio = voices[vix].formant_ratio;
                    grains[grain_ix].ix = 0;
                    grains[grain_ix].gain = (float) voices[vix].midivel / 127.0;
                    grains[grain_ix].pan = voices[vix].pan;
                    
                    if (voices[vix].ratio < 1)
                        grains[grain_ix].gain *= powf(1/voices[vix].ratio,0.5);
                    
                    voices[vix].nextgrain += (T / voices[vix].ratio);
                    
                    if (++grain_ix >= ngrains)
                        grain_ix = 0;
                }
            }
            
            *out = *in;
            *out2 = *in;
            
            for (int ix = 0; ix < ngrains; ix++)
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
                    float u = linear (cbuf + i, fi - i);
                    
                    float wi = 2 + graintablesize * (g.ix / g.size);
                    i = (int) wi;
                    float w = linear (grain_window + i, wi - i);
                    
                    *out += u * w * g.gain * (g.pan + 1.0)/2;
                    *out2 += u * w * g.gain * (-g.pan + 1)/2;
                    g.ix += g.ratio;
                    
                    if (g.ix > g.size)
                        g.size = -1;
                    
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
            if (k > 0 && cmdf2 > cmdf1 && cmdf1 < cmdf && cmdf1 < 0.1 && k > 50)
            {
                period = (float) (k-1) + 0.5*(cmdf2 - cmdf)/(cmdf2 + cmdf - 2*cmdf1); break;
            }
        }
        
        Tbuf[Tix++] = period;
        
        if (Tix >= 5)
            Tix = 0;
        
        memcpy(Tsrt, Tbuf, 5 * sizeof(float));
        vDSP_vsort(Tsrt, (vDSP_Length) 5, 1);
        
        return Tsrt[2];
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
        
        int srch_n = (int)T/2;
        
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
        
        pitchmark[0] += (mean/sum);
        
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
        
        // look for empty voice, or one with the same note and take that if we can
        for (int k = 3; k < nvoices; k++)
        {
            printf("voice %d: %d\n", k, voices[k].midinote);
            dist = abs(voices[k].lastnote - note);
            if (dist == 0 || (voices[k].midinote == -1 && dist < min_dist))
            {
                min_dist = dist;
                min_ix = k;
            }
        }
        if (min_ix >= 0)
        {
            voices[min_ix].lastnote = voices[min_ix].midinote;
            voices[min_ix].midinote = note;
            voices[min_ix].midivel = vel;
            voices[min_ix].sample_num = sample_count;
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
        float intervals[127];
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
                printf("%d, 7\n", (ix + 2) % 12);
            }
            
            if (octave[(ix+3)%12] && octave[(ix+6)%12])
            {
                printf("%d, diminished\n", ix);
            }
            
            if (octave[(ix+3)%12] && octave[(ix+7)%12])
            {
                printf("%d, minor\n", ix);
                root_key = ix + 12;
                break;
            }
            
            if (octave[(ix+4)%12] && octave[(ix+7)%12])
            {
                printf("%d, major\n", ix);
                root_key = ix;
                break;
            }
            
            if (octave[(ix+4)%12] && octave[(ix+8)%12])
            {
                printf("%d, augmented\n", ix);
            }
       
        }
        
        printf("\n");
        
    }
    
    void update_voices (void)
    {
        voices[0].error = 0;
        voices[0].ratio = 1.0;
        voices[0].target_ratio = 1.0;
        voices[0].formant_ratio = 1.0;
        voices[0].midivel = -1;
        voices[0].midinote = -1;
        voices[1].midinote = -1;
        voices[1].midivel = 65;
        voices[1].pan = 0.5;
        voices[2].midinote = -1;
        voices[2].midivel = 65;
        voices[2].pan = -0.5;
        
        if (midi_changed && (sample_count - midi_changed_sample_num) > (int) sampleRate / 50)
        {
            midi_changed = 0;
            printf("%d samples since last midi note\n", sample_count - midi_changed_sample_num);
            analyze_harmony();
        }
        
        
        if (!voiced)
        {
            note_number = -1.0;
            return;
        }
            
        float f = log2f (sampleRate / (T * 440));
        
        float note_f = f * 12.0;
        int nn = (int) round(note_f);
        float error = (note_f - (float)nn)/12;
        float error_ratio = powf(2.0, error);
        
        int root = root_key % 12;
        int quality = root_key / 12;
        
        int interval = (nn + 69 - root) % 12;
        note_number = (nn + 69) % 12 + (note_f - nn);

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
            voices[1].midinote = 0;
            voices[2].midinote = 0;
            voices[0].midinote = 0;
            
            if (quality == 0)
            {
                voices[1].target_ratio = major_chord_table[interval].r1;
                voices[2].target_ratio = major_chord_table[interval].r2;
            }
            else if (quality == 1)
            {
                voices[1].target_ratio = minor_chord_table[interval].r1;
                voices[2].target_ratio = minor_chord_table[interval].r2;
            }
            else if (quality == 2)
            {
                voices[1].target_ratio = blues_chord_table[interval].r1;
                voices[2].target_ratio = blues_chord_table[interval].r2;
            }
            else if (quality == 3)
            {
                voices[1].target_ratio = 1.0;
                voices[2].target_ratio = 1.0;
                voices[1].midinote = -1;
                voices[2].midinote = -1;
            }
            
            if (inversion < 2)
                voices[2].target_ratio *= 0.5;
            if (inversion < 1)
                voices[1].target_ratio *= 0.5;
        }
        
        for (int k = 3; k < nvoices; k++)
        {
            if (voices[k].midinote < 0)
                continue;
            
            voices[0].midinote = 0;
            
            float error_hsteps = (voices[k].midinote - 69) - note_f;
            
            voices[k].target_ratio = powf(2.0, error_hsteps/12);
        }
    
        for (int k = 0; k < nvoices; k++)
        {
            voices[k].target_ratio /= error_ratio;
            voices[k].ratio = 0.9 * voices[k].ratio + 0.1 * voices[k].target_ratio;
        }
    }
	
    // MARK: Member Variables

private:
	std::vector<FilterState> channelStates;
	BiquadCoefficients coeffs;
    int nfft = 2048;
    int l2nfft = 11;
    DSPSplitComplex fft_in, fft_out, fft_out2, fft_buf;
    float * cbuf;
    int ncbuf = 4096;
    int cix = 0;
    int rix = 0;
    float rcnt = 256;
    float T = 400;
    float Tbuf[5];
    float Tsrt[5];
    int Tix;
    float pitchmark[3] = {0,-1,-1};
    int maxT = 600; // note nfft should be bigger than 3*maxT
    int cmask = ncbuf - 1;
    int voiced = 0;
    FFTSetup fft_s;
	float sampleRate = 44100.0;
	float nyquist = 0.5 * sampleRate;
	float inverseNyquist = 1.0 / nyquist;
	AUAudioFrameCount dezipperRampDuration;
    int keycenter = 0;
    
    float midinotes[128];
    
    int nvoices = 16;
    int voice_ix = 3;
    int root_key = 0;
    int chord_quality = 0;
    voice_t * voices;
    int inversion = 2;
    int midi_enable = 1;
    int auto_enable = 1;
    int triad = -1;
    float intervals[12];
    triad_ratio_t triads[18];
    triad_ratio_t major_chord_table[12];
    triad_ratio_t minor_chord_table[12];
    triad_ratio_t blues_chord_table[12];
    
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
	// Parameters.
	ParameterRamper cutoffRamper = 400.0 / 44100.0;
	ParameterRamper resonanceRamper = 20.0;
};

#endif /* FilterDSPKernel_hpp */
