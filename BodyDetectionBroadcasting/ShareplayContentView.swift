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
struct ShareplayContentView: View {


    @ObservedObject var browserModel:NearbyServiceBrowserModel
    @ObservedObject var shareplayModel:ContentViewShareplayModel
    public var playerModel:PlayerModel
    #if os(visionOS)
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    #endif
    
    var body: some View {
        VStack {
#if os(visionOS)
            Toggle("Show immersive view", isOn: $showImmersiveSpace)
                .task {
                    for await dancingSession in DanceCoordinator.sessions() {
                        print("found coordinator session \(dancingSession.activity.id)")
                        shareplayModel.configureGroupSession(dancingSession)
                        playerModel.player.playbackCoordinator.coordinateWithSession(dancingSession)
                        playerModel.audioPlayer.playbackCoordinator.coordinateWithSession(dancingSession)
                    }
                }

            #endif
        }
        .padding()
        .onChange(of: shareplayModel.isActivated, { oldValue, newValue in
            if newValue, let groupSession = shareplayModel.groupSession, groupSession.activeParticipants.count > 1 {
                showImmersiveSpace = true
            } else {
                showImmersiveSpace = false
            }
        })
        .onChange(of: shareplayModel.groupSession?.state) { oldValue, newValue in
            if case .invalidated = newValue {
                shareplayModel.isActivated = false
            }
        }
#if os(visionOS)
        .onChange(of: showImmersiveSpace) { _, newValue in
            Task {
                if newValue {
                    switch await openImmersiveSpace(id: "ShareplayImmersiveSpace") {
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
    let shareplayModel = ContentViewShareplayModel()
    return ShareplayContentView(browserModel: model, shareplayModel: shareplayModel, playerModel: PlayerModel())
}
