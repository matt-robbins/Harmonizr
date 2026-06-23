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

    
    float trueT;
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

- (void)testHarm {
    
}

@end
