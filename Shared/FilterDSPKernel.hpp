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
#include <Accelerate/Accelerate.h>


typedef struct grain_s
{
    float size;
    float start;
    float ix;
    float ratio;
    float gain;
} grain_t;

typedef struct voice_s
{
    float error;
    float ratio;
    float formant_ratio;
    float nextgrain;
    int midinote;
    int midivel;
    int lastnote;
} voice_t;

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
    HarmParamQuality = 3,
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
        
        nvoices = 8;
        voices = (voice_t *) calloc(nvoices, sizeof(voice_t));
        voice_ix = 1;
        
        for (int k = 0; k < nvoices; k++)
        {
            voices[k].midinote = -1;
            voices[k].error = 0;
            voices[k].ratio = 1;
            voices[k].formant_ratio = 1;
            
            voices[k].nextgrain = 250;
        }
        
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
        //uint8_t channel = midiEvent.data[0] & 0x0F; // works in omni mode.
        
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
                addnote((int)note,127);
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
		
        // For each sample.
		for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex)
        {
            int frameOffset = int(frameIndex + bufferOffset);
			
            int channel = 0;
			
            float* in  = (float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
            float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;

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
                {
                    T = p;
                }
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
                finderror();
                
                //printf("pitchmark[0,1,2] = %.2f,%.2f,%.2f\ninput = %d\n", pitchmark[0],pitchmark[1],pitchmark[2],cix);
            }
            
            if (pitchmark[2] < 0)
                continue;
            
            for (int vix = 0; vix < nvoices; vix++)
            {
                if (voices[vix].midinote == -1)
                    continue;
                
                if (--voices[vix].nextgrain < 0)
                {
                    grains[grain_ix].size = 2 * T;
                    grains[grain_ix].start = pitchmark[1] - voices[vix].nextgrain - T;
                    grains[grain_ix].ratio = voices[vix].formant_ratio;
                    grains[grain_ix].ix = 0;
                    grains[grain_ix].gain = voices[vix].midivel / 127;
                    
                    voices[vix].nextgrain += (T / voices[vix].ratio);
                    
                    if (++grain_ix >= ngrains)
                        grain_ix = 0;
                }
            }
            
            *out = 0;
            
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
                    
                    *out += u * w;
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
        
        pitchmark[0] += (mean/sum);
        
        if (pitchmark[0] < 0)
            pitchmark[0] += ncbuf;
        else if (pitchmark[0] > ncbuf - 1)
            pitchmark[0] -= ncbuf;
    }
    void addnote(int note, int vel)
    {
        printf("adding note %d\n", note);
        for (int k = 1; k < nvoices; k++)
        {
            if (voices[k].midinote == -1)
            {
                voices[k].lastnote = voices[k].midinote;
                voices[k].midinote = note;
                voices[k].midivel = vel;
                return;
            }
        }
        
        voices[voice_ix].lastnote = voices[voice_ix].midinote;
        voices[voice_ix].midinote = note;
        voices[voice_ix].midinote = vel;
        
        if (++voice_ix > nvoices)
            voice_ix = 1;
    }
    
    void remnote(int note)
    {
        for (int k = 0; k < nvoices; k++)
        {
            if (voices[k].midinote == note)
            {
                voices[k].lastnote = voices[k].midinote;
                voices[k].midinote = -1;
                return;
            }
        }
    }
    void finderror (void)
    {
        voices[0].error = 0;
        voices[0].ratio = 1.0;
        voices[0].formant_ratio = 1.0;
        voices[0].midinote = 0;
        voices[1].midinote = 0;
        voices[2].midinote = 0;
        
        if (!voiced)
            return;
            
        float f = log2f (sampleRate / (T * 440));
        
        float note_f = f * 12.0;
        int nn = (int) round(note_f);
        float error = (note_f - (float)nn)/12;
        
        int root = root_key % 12;
        int quality = root_key / 12;
        
        int interval = (nn + 69 - root) % 12;
        note_number = interval;
        //printf("interval = %d\n", interval);
        if (quality == 0)
        {
            switch (interval)
            {
                case 0:
                case 5:
                case 10:
                    voices[1].ratio = powf(2.0f,4./12. - error);
                    voices[2].ratio = powf(2.0f,7./12. - error);
                    break;
                case 7:
                    voices[1].ratio = powf(2.0f,5./12. -error);
                    voices[2].ratio = powf(2.0f,9./12. -error);
                    break;
                case 2:
                    voices[1].ratio = powf(2.0f,3./12. -error);
                    voices[2].ratio = powf(2.0f,7./12. - error);
                    break;
                case 17:
                    voices[1].ratio = powf(2.0f,4./12. - error);
                    voices[2].ratio = powf(2.0f,9./12. - error);
                    break;
                case 4:
                    voices[1].ratio = powf(2.0f,3./12. - error);
                    voices[2].ratio = powf(2.0f,8./12. - error);
                    break;
                case 9:
                    voices[1].ratio = powf(2.0f,3./12. - error);
                    voices[2].ratio = powf(2.0f,7./12. - error);
                    break;
                case 8:
                    voices[1].ratio = powf(2.0f, 4./12. - error);
                    voices[2].ratio = powf(2.0f, 8./12. - error);
                    break;
                case 1:
                case 3:
                case 6:
                case 11:
                    voices[1].ratio = powf(2.0f,3./12. - error);
                    voices[2].ratio = powf(2.0f,6./12. - error);
                    break;
            }
        }
        else if (quality == 1)
        {
            switch (interval)
            {
                case 8:
                case 10:
                    voices[1].ratio = powf(2.0f,4./12.);
                    voices[2].ratio = powf(2.0f,7./12.);
                    break;
                case 5:
                    voices[1].ratio = powf(2.0f,3./12.);
                    voices[2].ratio = powf(2.0f,9./12.);
                    break;
                case 6:
                    voices[1].ratio = powf(2.0f,6./12.);
                    voices[2].ratio = powf(2.0f,8./12.);
                    break;
                case 17:
                    voices[1].ratio = powf(2.0f,5./12.);
                    voices[2].ratio = powf(2.0f,9./12.);
                    break;
                case 0:
                    voices[1].ratio = powf(2.0f,3./12.);
                    voices[2].ratio = powf(2.0f,7./12.);
                    break;
                case 3:
                    voices[1].ratio = powf(2.0f,4./12.);
                    voices[2].ratio = powf(2.0f,9./12.);
                    break;
                case 7:
                    voices[1].ratio = powf(2.0f,5./12.);
                    voices[2].ratio = powf(2.0f,8./12.);
                    break;
                case 14:
                    voices[1].ratio = powf(2.0f,3./12.);
                    voices[2].ratio = powf(2.0f,8./12.);
                    break;
                case 19:
                    voices[1].ratio = powf(2.0f,3./12.);
                    voices[2].ratio = powf(2.0f,7./12.);
                    break;
                case 1:
                case 2:
                case 4:
                case 9:
                case 11:
                    voices[1].ratio = powf(2.0f,3./12.);
                    voices[2].ratio = powf(2.0f,6./12.);
                    break;
            }
        }
        else if (quality == 2)
        {
            switch (interval)
            {
                case 3:
                case 5:
                case 6:
                case 8:
                case 9:
                case 11:
                    voices[1].ratio = powf(2.0f,4./12.);
                    voices[2].ratio = powf(2.0f,7./12.);
                    break;
                case 17:
                    voices[1].ratio = powf(2.0f,5./12.);
                    voices[2].ratio = powf(2.0f,9./12.);
                    break;
                case 0:
                    voices[1].ratio = powf(2.0f,4./12.);
                    voices[2].ratio = powf(2.0f,10./12.);
                    break;
                case 2:
                    voices[1].ratio = powf(2.0f,2./12.);
                    voices[2].ratio = powf(2.0f,8./12.);
                    break;
                case 1:
                    voices[1].ratio = powf(2.0f,3./12.);
                    voices[2].ratio = powf(2.0f,9./12.);
                case 7:
                    voices[1].ratio = powf(2.0f,3./12.);
                    voices[2].ratio = powf(2.0f,5./12.);
                    break;
                case 10:
                    voices[1].ratio = powf(2.0f,2./12.);
                    voices[2].ratio = powf(2.0f,6./12.);
                    break;
                case 19:
                    voices[1].ratio = powf(2.0f,3./12.);
                    voices[2].ratio = powf(2.0f,7./12.);
                    break;
                case 4:
                    voices[1].ratio = powf(2.0f,3./12.);
                    voices[2].ratio = powf(2.0f,6./12.);
                    break;
            }
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
    
    int nvoices = 8;
    int voice_ix = 1;
    int root_key = 0;
    int chord_quality = 0;
    voice_t * voices;
    
    int ngrains;
    int grain_ix = 0;
    grain_t * grains;
    
    int graintablesize = maxT;
    float * grain_window;

	AudioBufferList* inBufferListPtr = nullptr;
	AudioBufferList* outBufferListPtr = nullptr;

public:

    float note_number;
	// Parameters.
	ParameterRamper cutoffRamper = 400.0 / 44100.0;
	ParameterRamper resonanceRamper = 20.0;
};

#endif /* FilterDSPKernel_hpp */
