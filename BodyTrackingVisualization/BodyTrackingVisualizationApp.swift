//
//  BodyTrackingVisualizationApp.swift
//  BodyTrackingVisualization
//
//  Created by Michael A Edgcumbe on 2/13/24.
//

import SwiftUI

@main
struct BodyTrackingVisualizationApp: App {
    
    @StateObject var browserModel = NearbyServiceBrowserModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(browserModel: browserModel)
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView(browserModel: browserModel)
        }
    }
}
