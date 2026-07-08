//
//  HarmonizerFrameworkTests.m
//  HarmonizerFrameworkTests
//
//  Created by Matthew E Robbins on 4/19/23.
//

#import <XCTest/XCTest.h>
//#import "Harmonizer.h"
#import "../harmonizr-dsp/HarmonizerDSPKernel.hpp"
#import "../harmonizr-dsp/Window.hpp"
#import "../harmonizr-dsp/CircularAudioBuffer.hpp"
#import "../harmonizr-dsp/PitchEstimator.hpp"
#import "../harmonizr-dsp/NoiseGate.hpp"
#import "../harmonizr-dsp/SpectralProcessor.hpp"
#import "../harmonizr-dsp/IntervalTable.hpp"
#import "../harmonizr-dsp/Harmonizer.hpp"
#include "TestAudioData.h"

static float audioValue(int k, float trueT) {
    return cos(k * 2*M_PI / trueT) + sin(k * 4*M_PI/trueT);
}

@interface HarmonizerFrameworkTests : XCTestCase

@end

@implementation HarmonizerFrameworkTests {
    HarmonizerDSPKernel k;
    Window *w; // = Window(Window::Hann, 64);
    Window *w2;
    CircularAudioBuffer *b;
    PitchEstimator *p;
    PitchEstimator *p2;
    NoiseGate *g;
    //SpectralProcessor *r;
    
    std::vector<SpectralProcessor> freezers;
    
    
    FFTSetup fft_s;
    DSPSplitComplex fft_in, fft_out, fft_buf;
    
    float trueT;
    int l2nfft;
    int nfft;
}

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    k.init(2, 2, 44100);
    
    w = new Window(Window::Hann, 64);
    w2 = new Window(Window::Hamm, 1024);
    b = new CircularAudioBuffer(11);
    // int MaxT, int l2nfft, float thresh, int nmed
    p = new PitchEstimatorYIN(500, 11, 0.5, 7);
    p2 = new PitchEstimatorSHS();
    
    g = new NoiseGate(-10.0f, 6.f, 10000, 1.0f);
    
    l2nfft = 11;
    nfft = 0x01 << l2nfft;
    fft_s = vDSP_create_fftsetup(l2nfft, 2);

    fft_alloc(fft_in, nfft);
    fft_alloc(fft_out, nfft);
    fft_alloc(fft_buf, nfft);

    //r = new SpectralProcessor(7,4);
    freezers.reserve(1);
    freezers.emplace_back(7,4);
    
    trueT = 117.2;
    
    for (int k = 0; k < 5000; k++) {
        b->pushValue(audioValue(k, trueT));
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    
    delete w;
    delete w2;
    delete b;
    delete p;
    delete g;
    //delete r;
}

- (void) testVoiceCalculations {
    k.setParameter(HarmParamNvoices, 4.0);
    k.set_T(400.f);
    k.setPreset(HarmPresetChords);
    k.set_voiced(true);
    k.update_voices();
    k.update_voices(); // one more to take care of hysteresis

    
    k.list_intervals();
}

- (void) testFFTPerformance1 {
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        for (int i = 0; i < 10000; i++){
            vDSP_fft_zopt(fft_s, &fft_in, 1, &fft_out, 1, &fft_buf, l2nfft, FFT_FORWARD);
        }
    }];
}

- (void) testFFTPerformance2 {
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        for (int i = 0; i < 10000; i++){
            vDSP_fft_zrip(fft_s, &fft_in, 1, l2nfft, FFT_FORWARD);
        }
    }];
}


- (void)testPitch {
    float T = 0;
    for (int k = 0; k < 4; k++)
        T = p->estimate(*b);
    XCTAssert(fabs(T-trueT) < 1.0);
}

- (void)testGate {
    for (int k = 0; k < 10000; k++)
        g->compute_one(0.0);
    XCTAssert(g->get_gain() < 0.1);
    
    for (int k = 0; k < 10000; k++)
        g->compute_one(1.0);
    XCTAssert(g->get_gain() > 0.9);
    
    for (int k = 0; k < 10000; k++)
        g->compute_one(0.0);
    XCTAssert(g->get_gain() > 0.9);
    
    for (int k = 0; k < 10000; k++)
        g->compute_one(0.0);
    XCTAssert(g->get_gain() < 0.1);
    
}

- (void)testWindow {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct results.
    XCTAssert(fabs(w->value(0.5) - 1.0) < 0.001);
    XCTAssert(fabs(w->value(0.25) - 0.5) < 0.001);
    
    XCTAssert(fabs(w2->value(0) - 0.08) < 0.001);
    XCTAssert(fabs(w2->value(0.25) - 0.54) < 0.001);
}

- (void)testPitchPerformance {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        for (int i = 0; i < 10000; i++){
            b->pushValue(audioValue(i, trueT));
            p->estimate(*b);
        }
    }];
}

- (void)testSpectral {
//    std::vector<SpectralProcessor> freezers = { {7,4}, {7,4}};
    freezers[0].freeze(true);
    for (int k = 0; k < 1000; k++) {
        float x = freezers[0].process_frame((float) sinf(2*M_PI*k/32));
        std::cout << x << ",";
    }
    std::cout << "\n";
    
}

- (void)testOlap {
    int N = 16;
    OlapAddBuffer ob = {4,N};
    float data[] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
    
    for (int k = 0; k < 40; k++) {
        float o = ob.olapAdd();
        int ck = ob.check();
        switch (ck) {
            case -1:
                break;
            default:
                memcpy(ob.get_current(), data, N * sizeof(float));
                break;
        }
        std::cout << o << ",";
    }
    std::cout << "\n";
    
}

- (void)testStateVariable {
    StateMemVariable<float> m = {0.0};
    
    m.set(2.0);
    XCTAssert(m.prev() == 0.0);
    m.set(1.0);
    XCTAssert(m.prev() == 2.0);
    XCTAssert(m.value() == 1.0);
}

- (void)testIntervalTable {
    int voices = 4;
    int types = 3;
    int tet = 12;
    
    IntervalTable tab = IntervalTable(voices, types, tet);
    int chords_intervals[] = {
        0,4,7,12, -1,3,6,11, 2,5,10,14, 1,4,9,13, 0,3,8,12, -1,2,7,11, 1,6,10,13, 0,5,9,12, -1,4,8,11, 0,3,7,10, 2,6,9,14, 1,5,8,13, // major
        0,3,7,12, -1,2,6,11, 1,5,10,13, 0,4,9,12, -1,3,8,11, -1,2,7,10, 1,6,9,13, 0,5,8,12, 0,4,7,11, 0,3,6,10, 0,5,9,14, 1,4,8,13, // minor
        0,4,10,12, -1,3,9,11, -2,2,8,10, 1,4,7,9, 0,3,6,8, 2,5,7,11, 1,4,6,10, 0,3,5,9, -1,2,4,8, 1,3,7,10, 0,2,6,9, -1,1,5,8, //dom
    };
    
    tab.setAll(chords_intervals, 4*3*12);
    XCTAssert(tab.getInterval(0,0,2) == 2);
    tab.setInterval(0,0,2,3);
    XCTAssert(tab.getInterval(0,0,2) == 3);
    
    XCTAssert(tab.getInterval(3,1,2) == 13);
}

- (void)testIir {
    IirTracker i {0.99};
    float t = 20;
    i.setT(t);
    for (int k = 0; k < (int) t*5; k++) {
        float v = i.compute(1.0);
        std::cout << v << ",";
        if (v > 0.9) {
            std::cout << "\ncompleted in " << k << " samples\n";
            break;
        }
    }
}

- (void)testStateMem {
    StateMemVariable<float> v=1.0;
    
    XCTAssert(v==1.0f);
    v = 0.f;
    //std::cout << "current value: " << v.value() << "? " << v << "\n";
    XCTAssert(v==0.0f);
    XCTAssert(v.prev()==1.0f);
    
    float vv = v;
    
    XCTAssert(vv == 0.f);
}

- (void)testHarm {
    float T = midi_note_to_T(66,44100);
    std::cout << "note 66: T=" << T << "\n";
    
}

@end
