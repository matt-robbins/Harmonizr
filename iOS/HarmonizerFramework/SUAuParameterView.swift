//
//  AuParameterView.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 4/9/26.
//

import SwiftUI
import AudioUnit



struct AuParameterView: View {
    @State var param: AUParameter
    var body: some View {
        HStack(alignment: .top, content: {
            // name and status
            VStack(alignment: .leading, content: {
                Text(param.displayName)
                if (param.unit == AudioUnitParameterUnit.decibels) {
                    
                }
            })
            
            Spacer()
            // icon and button
//            Image(systemName: "globe")
//                .imageScale(.large)
//                .foregroundStyle(.tint)
            Image(systemName: "bell")
                .imageScale(.large)
                .foregroundStyle(.tint)
                //.background(RoundedRectangle(cornerRadius: 4).stroke())
        })
        
    }
    
    
}

#Preview {
    AuParameterView(param: AUParameterTree.createParameter(
        withIdentifier: "testParam",
        name: "Test Parameter",
        address: 0,
        min: 0.0,
        max: 100.0,
        unit: .percent,
        unitName: nil,
        flags: [.flag_IsReadable, .flag_IsWritable],
        valueStrings: nil,
        dependentParameters: nil
    ))
}
