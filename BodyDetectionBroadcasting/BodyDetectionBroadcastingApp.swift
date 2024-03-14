//
//  BodyTrackingVisualizationApp.swift
//  BodyTrackingVisualization
//
//  Created by Michael A Edgcumbe on 2/13/24.
//

import SwiftUI

@main
struct BodyDetectionBroadcastingApp: App {
    
    @StateObject var browserModel = NearbyServiceBrowserModel()
    @StateObject var shareplayModel = ContentViewShareplayModel()
    
    @State private var useShareplay = true
    var body: some Scene {
        WindowGroup {
            if useShareplay {
                ShareplayContentView(browserModel: browserModel, shareplayModel: shareplayModel)
            } else {
                MultipeerContentView(browserModel: browserModel)
            }
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView(browserModel: browserModel)
        }
        
        ImmersiveSpace(id: "ShareplayImmersiveSpace") {
            ShareplayImmersiveView(browserModel: shareplayModel)
        }
    }
}
