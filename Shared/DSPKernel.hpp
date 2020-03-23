/*
	<samplecode>
		<abstract>
			Utility code to manage scheduled parameters in an audio unit implementation.
		</abstract>
	</samplecode>
*/

#ifndef DSPKernel_h
#define DSPKernel_h

#ifdef __APPLE__
#import <AudioToolbox/AudioToolbox.h>
#import <algorithm>

typedef AUAudioFrameCount frame_count_t;
typedef AUParameterAddress param_address_t;
typedef AUValue value_t;
typedef AudioTimeStamp timestamp_t;

#if TARGET_IPHONE_SIMULATOR
// iOS Simulator
#elif TARGET_OS_IPHONE
// iOS device
#elif TARGET_OS_MAC
// Other kinds of Mac OS
#else
#   error "Unknown Apple platform"
#endif
#endif

//#import <AudioToolbox/AudioToolbox.h>
//#import <algorithm>

template <typename T>
T clamp(T input, T low, T high) {
	return std::min(std::max(input, low), high);
}

// Put your DSP code into a subclass of DSPKernel.
class DSPKernel {
public:
	virtual void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset) = 0;
	virtual void startRamp(AUParameterAddress address, AUValue value, AUAudioFrameCount duration) = 0;
	
	// Override to handle MIDI events.
	virtual void handleMIDIEvent(AUMIDIEvent const& midiEvent) {}
	
	void processWithEvents(AudioTimeStamp const* timestamp, AUAudioFrameCount frameCount, AURenderEvent const* events, AUMIDIOutputEventBlock midiOut);
        
    dispatch_semaphore_t sem;
    int program_num;
    int cc;
    int cc_num;

private:
	void handleOneEvent(AURenderEvent const* event);
	void performAllSimultaneousEvents(AUEventSampleTime now, AURenderEvent const*& event);
};

#endif /* DSPKernel_h */
