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

enum ModelFit : String {
    case GageDarkFit
    case GageLightFit
    case JesseDarkFit
    case JesseLightFit
    case DeanDarkFit
    case DeanLightFit
}

struct MultipeerContentView: View {
    @ObservedObject var browserModel:NearbyServiceBrowserModel
#if os(visionOS)
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
#endif
    
    @State private var gageDarkFitEntity: ModelEntity = ModelEntity()
    @State private var gageLightFitEntity: ModelEntity?
    @State private var jesseDarkFitEntity: ModelEntity?
    @State private var jesseLightFitEntity: ModelEntity?
    @State private var deanLightFitEntity:ModelEntity?
    @State private var deanDarkFitEntity:ModelEntity?
    
    @State private var gageDarkFitAnchor = AnchorEntity()
    @State private var gageLightFitAnchor = AnchorEntity()
    @State private var jesseDarkFitAnchor = AnchorEntity()
    @State private var jesseLightFitAnchor = AnchorEntity()
    @State private var deanLightFitAnchor = AnchorEntity()
    @State private var deanDarkFitAnchor = AnchorEntity()
    
    @Binding public var selectedFit:ModelFit?
    
    var body: some View {
        if browserModel.isConnected {
#if os(visionOS)
            VStack {
                if showImmersiveSpace {
                    HStack {
                        Button {
                            showImmersiveSpace = false
                            browserModel.leaveSession()
                            browserModel.startBrowsing()
                        } label: {
                            Label("Quit", systemImage: "xmark")
                        }
                        Spacer()
                        Button {
                            
                        } label: {
                            Label("Now Playing", systemImage: "play")
                        }
                    }
                }
                Spacer()
                Text("Select a model")
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack {
                        VStack {
                            Image("gage_darkfit")                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth:640, maxHeight:640)
                                .background()
                            Button {
                                selectedFit = .GageDarkFit
                                showImmersiveSpace = true
                            } label: {
                                Label("Dark Gage", systemImage: "star.fill")
                            }.padding()
                        }
                        VStack {
                            Image("gage_lightfit")                                
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth:640, maxHeight:640)
                                .background()
                            Button {
                                selectedFit = .GageLightFit
                                showImmersiveSpace = true
                            } label: {
                                Label("Light Gage", systemImage: "star.fill")
                            }.padding()
                        }
                        VStack {
                            Image("jesse_darkfit")                                .resizable()
                                .aspectRatio(contentMode: .fit)

                                .frame(maxWidth:640, maxHeight:640)

                                .background()
                            
                            Button {
                                selectedFit = .JesseDarkFit
                                showImmersiveSpace = true
                            } label: {
                                Label("Dark Jesse", systemImage: "star.fill")
                            }.padding()
                        }
                        VStack {
                            Image("jesse_lightfit")                                .resizable()
                                .aspectRatio(contentMode: .fit)

                                .frame(maxWidth:640, maxHeight:640)

                                .background()
                            Button {
                                selectedFit = .JesseLightFit
                                showImmersiveSpace = true
                            } label: {
                                Label("Light Jesse", systemImage: "star.fill")
                            }.padding()
                        }
                        VStack {
                            Image("dean_darkfit")
                                .resizable()
                                .aspectRatio(contentMode: .fit)

                                .frame(maxWidth:640, maxHeight:640)
                                .background()
                            Button {
                                selectedFit = .DeanDarkFit
                                showImmersiveSpace = true
                            } label: {
                                Label("Dark Dean", systemImage: "star.fill")

                            }.padding()
                        }
                        VStack {
                            Image("dean_lightfit")                                .resizable()
                                .aspectRatio(contentMode: .fit)

                                .frame(maxWidth:640, maxHeight:640)

                                .background()
                            Button {
                                selectedFit = .DeanLightFit
                                showImmersiveSpace = true
                            } label: {
                                Label("Light Dean", systemImage: "star.fill")
                            }.padding()
                        }
                    }
                    Spacer()
                }.padding()
            }.padding()
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
        } else {
            NearbyServiceBrowser(model: browserModel)
        }
    }
}

#Preview() {
    let model = NearbyServiceBrowserModel()
    return MultipeerContentView(browserModel: model, selectedFit: .constant(.GageDarkFit))
}

