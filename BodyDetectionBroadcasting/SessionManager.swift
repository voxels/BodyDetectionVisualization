//
//  SessionManager.swift
//  BodyTrackingVisualization
//
//  Created by Michael A Edgcumbe on 3/1/24.
//

import Foundation
import ARKit
import RealityKit
import QuartzCore
import SwiftUI

open class SessionManager: ObservableObject {
    public let worldTracking:WorldTrackingProvider = WorldTrackingProvider()
    private let handTracking:HandTrackingProvider = HandTrackingProvider()
    var arkitSession = ARKitSession()
    var providersStoppedWithError = false
    var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    var handTrackingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined

    public let deviceLocation: Entity = Entity()
    public let leftHandLocation:Entity = Entity()
    public let rightHandLocation:Entity = Entity()
    
    var allRequiredAuthorizationsAreGranted: Bool {
        worldSensingAuthorizationStatus == .allowed
    }

    var allRequiredProvidersAreSupported: Bool {
        WorldTrackingProvider.isSupported
    }
    
    var canEnterImmersiveSpace: Bool {
        allRequiredAuthorizationsAreGranted && allRequiredProvidersAreSupported
    }

    func requestWorldSensingAuthorization() async {
        print("request authorization")
        let authorizationResult = await arkitSession.requestAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }
    
    func requestHandsTrackingAuthorization() async {
        let authorizationResult = await arkitSession.requestAuthorization(for: [.handTracking])
        handTrackingAuthorizationStatus = authorizationResult[.handTracking]!
    }
    
    func queryWorldSensingAuthorization() async {
        let authorizationResult = await arkitSession.queryAuthorization(for: [.worldSensing])
        worldSensingAuthorizationStatus = authorizationResult[.worldSensing]!
    }
    
    func queryHandTrackingAuthorization() async {
        let authorizationResult = await arkitSession.queryAuthorization(for: [.handTracking])
        handTrackingAuthorizationStatus = authorizationResult[.worldSensing]!
    }


    func monitorSessionEvents() async {
        for await event in arkitSession.events {
            switch event {
            case .dataProviderStateChanged(_, let newState, let error):
                switch newState {
                case .initialized:
                    break
                case .running:
                    break
                case .paused:
                    break
                case .stopped:
                    if let error {
                        print("An error occurred: \(error)")
                        providersStoppedWithError = true
                    }
                @unknown default:
                    break
                }
            case .authorizationChanged(let type, let status):
                print("Authorization type \(type) changed to \(status)")
                if type == .worldSensing {
                    worldSensingAuthorizationStatus = status
                }
                if type == .handTracking {
                    handTrackingAuthorizationStatus = status
                }
            default:
                print("An unknown event occured \(event)")
            }
        }
    }
    
    @MainActor
    func runARKitSession() async {
        print("run session")

        do {
            // Run a new set of providers every time when entering the immersive space.
            try await arkitSession.run([worldTracking, handTracking])
        } catch {
            print(error)
            return
        }
        
        
    }
    
    @MainActor
    func processDeviceAnchorUpdates() async {
        await run(function: self.queryAndProcessLatestDeviceAnchor, withFrequency: 90)
    }
    
    @MainActor
    private func queryAndProcessLatestDeviceAnchor() async {
        // Device anchors are only available when the provider is running.
        guard worldTracking.state == .running else { return }
        
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
        
        guard let deviceAnchor, deviceAnchor.isTracked else { return }
        await updateDevicePlacementLocation(deviceAnchor)
        
        let handAnchor = handTracking.latestAnchors
        let leftHandAnchor:HandAnchor? = handAnchor.leftHand
        let rightHandAnchor:HandAnchor? = handAnchor.rightHand
        
        if let leftHandAnchor, leftHandAnchor.isTracked {
            await updateLeftHandPlacementLocation(leftHandAnchor)
        }
        
        if let rightHandAnchor, rightHandAnchor.isTracked {
            await updateRightHandPlacementLocation(rightHandAnchor)
        }
    }


    @MainActor
    private func updateDevicePlacementLocation(_ deviceAnchor: DeviceAnchor) async {
        deviceLocation.transform = Transform(matrix: deviceAnchor.originFromAnchorTransform)
    }

    @MainActor
    private func updateLeftHandPlacementLocation(_ handAnchor: HandAnchor) async {
        leftHandLocation.transform = Transform(matrix: handAnchor.originFromAnchorTransform)
    }

    @MainActor
    private func updateRightHandPlacementLocation(_ handAnchor: HandAnchor) async {
        rightHandLocation.transform = Transform(matrix: handAnchor.originFromAnchorTransform)
    }
}


extension SessionManager {
    /// Run a given function at an approximate frequency.
    ///
    /// > Note: This method doesn’t take into account the time it takes to run the given function itself.
    @MainActor
    func run(function: () async -> Void, withFrequency hz: UInt64) async {
        while true {
            if Task.isCancelled {
                return
            }
            
            // Sleep for 1 s / hz before calling the function.
            let nanoSecondsToSleep: UInt64 = NSEC_PER_SEC / hz
            do {
                try await Task.sleep(nanoseconds: nanoSecondsToSleep)
            } catch {
                // Sleep fails when the Task is cancelled. Exit the loop.
                return
            }
            
            await function()
        }
    }
}
