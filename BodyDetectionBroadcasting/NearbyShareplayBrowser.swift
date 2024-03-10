//
//  NearbyShareplayBrowser.swift
//  BodyTrackingVisualization
//
//  Created by Michael A Edgcumbe on 3/6/24.
//

import SwiftUI

struct NearbyShareplayBrowser: View {
    @ObservedObject var shareplayModel:ContentViewShareplayModel

    var body: some View {
        Button("Join circle") {
            Task {
                do {
                    try await shareplayModel.startAdvertisingDevice()
                } catch {
                    print(error)
                }
            }
        }
        .onAppear(perform: {
            Task { @MainActor in
                do{
                    await shareplayModel.createCoordinator()
                } catch {
                    print(error)
                }
            }
        })
    }
}

#Preview {
    let shareplayModel = ContentViewShareplayModel()

    return  NearbyShareplayBrowser(shareplayModel: shareplayModel)
}
