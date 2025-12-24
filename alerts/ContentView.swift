//
//  ContentView.swift
//  alerts
//
//  Created by Jonatas Gomes on 2025-12-23.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        AlertListView()
            .preferredColorScheme(nil) // Respects system setting
    }
}

#Preview("Dark Mode") {
    ContentView()
        .preferredColorScheme(.dark)
}

#Preview("Light Mode") {
    ContentView()
        .preferredColorScheme(.light)
}
