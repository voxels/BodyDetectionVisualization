//
//  NearbyServiceBrowser.swift
//  BodyTrackingVisualization
//
//  Created by Michael A Edgcumbe on 2/13/24.
//

import SwiftUI
import MultipeerConnectivity

struct NearbyServiceBrowser: View {
    @ObservedObject public var model:NearbyServiceBrowserModel

    var body: some View {
        ServiceBrowserContainer(model: model)
            .padding(24)
            .onAppear(perform: {
                model.startBrowsing()
            })
            .onDisappear(perform: {
                model.stopBrowsing()
            })
        
    }
}

struct ServiceBrowserContainer: UIViewControllerRepresentable {
    typealias UIViewControllerType = MCBrowserViewController
    
    @ObservedObject public var model:NearbyServiceBrowserModel

    func makeUIViewController(context: Context) -> MCBrowserViewController {
        let vc = MCBrowserViewController(browser: model.browser, session: model.session)
        vc.delegate = model
        vc.maximumNumberOfPeers = 2 
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MCBrowserViewController, context: Context) {
    }
}

#Preview {
    let model = NearbyServiceBrowserModel()
    return NearbyServiceBrowser(model: model)
}
