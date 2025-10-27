//
//  ContentView.swift
//  PhotoCleaner
//
//  Created by Welly_luo on 4/21/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var photoManager: PhotoManager
    
    var body: some View {
        MainTabView()
            .environmentObject(photoManager)
    }
}

#Preview {
    ContentView()
        .environmentObject(PhotoManager())
}
