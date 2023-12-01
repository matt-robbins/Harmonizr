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
    
    float trueT;
}

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    k.init(2, 2, 44100);
    w = new Window(Window::Hann, 64);
    w2 = new Window(Window::Hamm, 1024);
    b = new CircularAudioBuffer(4096);
    // int MaxT, int l2nfft, float thresh, int nmed
    p = new PitchEstimatorYIN(500, 11, 0.5, 7);
    p2 = new PitchEstimatorSHS();
    
    trueT = 117.2;
    
    for (int k = 0; k < 5000; k++) {
        b->insertValue(audioValue(k, trueT));
    }
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    
    delete w;
    delete w2;
    delete b;
    delete p;
}

- (void)testPitch {
    float T = 0;
    for (int k = 0; k < 4; k++)
        T = p->estimate(*b);
    XCTAssert(fabs(T-trueT) < 1.0);
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
            b->insertValue(audioValue(i, trueT));
            p->estimate(*b);
        }
    }];
}

@end
