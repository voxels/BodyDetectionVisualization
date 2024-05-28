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
    public var playerModel = PlayerModel()
    @State private var selectedFit:ModelFit?

    @State private var useShareplay = false
    var body: some Scene {
        WindowGroup {
            if useShareplay {
                ShareplayContentView(browserModel: browserModel, shareplayModel: shareplayModel, playerModel: playerModel)
            } else {
                MultipeerContentView(browserModel: browserModel, selectedFit: $selectedFit)
            }
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView(browserModel: browserModel, playerModel: playerModel, selectedFit: $selectedFit)
        }
        
        ImmersiveSpace(id: "ShareplayImmersiveSpace") {
            ShareplayImmersiveView(browserModel: shareplayModel, playerModel: playerModel)
        }
    }
}
