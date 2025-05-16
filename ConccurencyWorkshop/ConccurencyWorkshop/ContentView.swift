//
//  ContentView.swift
//  ConccurencyWorkshop
//
//  Created by Laura Calinoiu on 16.05.2025.
//

import SwiftUI

struct ContentView: View {
    @State private var program = Program()
    
    var body: some View {
        Text("Hello, world!").onAppear {
            program.run()
        }
    }
}

#Preview {
    ContentView()
}
