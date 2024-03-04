//
//  ContentView.swift
//  BodyTrackingVisualization
//
//  Created by Michael A Edgcumbe on 2/13/24.
//

import SwiftUI
import RealityKit

import MultipeerConnectivity
#if os(visionOS)
import RealityKitContent
#endif
struct ContentView: View {


    @ObservedObject var browserModel:NearbyServiceBrowserModel
    #if os(visionOS)
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    #endif
    var body: some View {
        VStack {
            if browserModel.isConnected {
#if os(visionOS)
            Toggle("Show Immersive Space", isOn: $showImmersiveSpace)
                .toggleStyle(.button)
            #endif
            } else {
                NearbyServiceBrowser(model: browserModel)
            }

        }
        .padding()
#if os(visionOS)
        .onChange(of: showImmersiveSpace) { _, newValue in
            Task {
                if newValue {
                    switch await openImmersiveSpace(id: "ImmersiveSpace") {
                    case .opened:
                        immersiveSpaceIsShown = true
                    case .error, .userCancelled:
                        fallthrough
                    @unknown default:
                        immersiveSpaceIsShown = false
                        showImmersiveSpace = false
                    }
                } else if immersiveSpaceIsShown {
                    await dismissImmersiveSpace()
                    immersiveSpaceIsShown = false
                }
            }
        }
#endif
    }
}

#Preview() {
    let  model = NearbyServiceBrowserModel()
    return ContentView(browserModel: model)
}
