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
    public var meshEntity = Entity()
    public var meshEntities = [UUID: ModelEntity]()
    public var floorEntities = [UUID: ModelEntity]()
    public let worldTracking:WorldTrackingProvider = WorldTrackingProvider()
    private let handTracking:HandTrackingProvider = HandTrackingProvider()
    let sceneReconstruction = SceneReconstructionProvider()

    var arkitSession = ARKitSession()
    var providersStoppedWithError = false
    var worldSensingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined
    var handTrackingAuthorizationStatus = ARKitSession.AuthorizationStatus.notDetermined

    public let deviceLocation: Entity = Entity()
    public let deviceOrigin:Entity = Entity()
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
            try await arkitSession.run([worldTracking, handTracking, sceneReconstruction])
        } catch {
            print(error)
            return
        }
        
        
    }
    
    @MainActor
    func processDeviceAnchorUpdates() async {
        await asyncRun(function: self.queryAndProcessLatestDeviceAnchor, withFrequency: 30)
    }
    
    /// Updates the scene reconstruction meshes as new data arrives from ARKit.
    @MainActor
    func processReconstructionUpdates() async {
        for await update in sceneReconstruction.anchorUpdates {
            let meshAnchor = update.anchor
            
            guard let shape = try? await ShapeResource.generateStaticMesh(from: meshAnchor) else { continue }
            switch update.event {
            case .added:
                let entity = ModelEntity()
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision = CollisionComponent(shapes: [shape], isStatic: true)
                entity.components.set(InputTargetComponent())
                
                entity.physicsBody = PhysicsBodyComponent(mode: .static)
                meshEntities[meshAnchor.id] = entity
                meshEntity.addChild(entity)
            case .updated:
                guard let entity = meshEntities[meshAnchor.id] else { continue }
                entity.transform = Transform(matrix: meshAnchor.originFromAnchorTransform)
                entity.collision?.shapes = [shape]

            case .removed:
                meshEntities[meshAnchor.id]?.removeFromParent()
                meshEntities.removeValue(forKey: meshAnchor.id)
            }
        }
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
    private func updateDevicePlacementLocation(_ deviceAnchor: DeviceAnchor) async
    {
        if deviceOrigin.name.isEmpty {
            deviceOrigin.transform = Transform(matrix:deviceAnchor.originFromAnchorTransform)
            deviceOrigin.name = "deviceOrigin"
        }
        
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
    /// > Note: This method doesn’t take into account the time it takes to run the given function itself
    ///
    func run(function: () -> Void, withFrequency hz: UInt64) async {
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
            
            function()
        }
    }
    
    func asyncRun(function: () async -> Void, withFrequency hz: UInt64) async {
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
