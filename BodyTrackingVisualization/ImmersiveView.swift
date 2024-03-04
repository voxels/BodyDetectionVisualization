//
//  ImmersiveView.swift
//  BodyTrackingVisualization
//
//  Created by Michael A Edgcumbe on 2/13/24.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @ObservedObject var browserModel:NearbyServiceBrowserModel
    @StateObject private var sessionManager:SessionManager = SessionManager()
    @State private var sceneEntity:Entity?
    @State private var originEntity:Entity?
    @State private var skeletonEntity: ModelEntity?
    @State private var skeletonIdentityEntity: ModelEntity?
    @State private var characterOffset: SIMD3<Float> = [0, 0, 0] // Offset the character by one meter to the left
    @State private var characterAnchor = Entity()
    @State private var characterLeftHandAnchor = Entity()
    @State private var characterRightHandAnchor = Entity()
    @State private var characterLeftFootAnchor = Entity()
    @State private var characterRightFootAnchor = Entity()

    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            do{
                let scene = try await Entity(named: "Immersive", in: realityKitContentBundle)
                sceneEntity = scene
                originEntity = Entity()
                originEntity?.position = SIMD3.zero
                content.add(scene)
                print(scene)
                if let model = scene.findEntity(named: "biped_robot_ace_skeleton") as? ModelEntity {
                    //print(model.name)
                    print("Found skeleton")
                    skeletonEntity = model
                    skeletonIdentityEntity = model.clone(recursive:true)
                    
                    //character?.setPosition(characterOffset, relativeTo: nil)
                }
                if let anchor = scene.findEntity(named: "characterAnchor") {
                    print("Found character anchor")
                    characterAnchor = anchor
                    characterAnchor.setPosition(characterOffset, relativeTo: nil)
                }
                
                if let anchor = scene.findEntity(named:"handAnchor_left") {
                    print("Found left hand anchor")
                    characterLeftHandAnchor = anchor
                }
                
                if let anchor = scene.findEntity(named: "handAnchor_right") {
                    print("Found right hand anchor")
                    characterRightHandAnchor = anchor
                }
                
                if let anchor = scene.findEntity(named:"footAnchor_left") {
                    print("Found left foot anchor")
                    characterLeftFootAnchor = anchor
                }
                
                if let anchor = scene.findEntity(named: "footAnchor_right") {
                    print("Found right foot anchor")
                    characterRightFootAnchor = anchor
                }

                
                scene.addChild(sessionManager.deviceLocation)
                scene.addChild(sessionManager.leftHandLocation)
                scene.addChild(sessionManager.rightHandLocation)
            } catch {
                print(error)
            }
        }
        .task {
            // Monitors changes in authorization. For example, the user may revoke authorization in Settings.
            await sessionManager.monitorSessionEvents()
        }
        .task {
            await sessionManager.requestWorldSensingAuthorization()
            await sessionManager.requestHandsTrackingAuthorization()
            await sessionManager.runARKitSession()
        }
        .task {
            await sessionManager.processDeviceAnchorUpdates()
        }
        .onChange(of: browserModel.displayLinkTimestamp ) { oldValue, newValue in
            if let sceneEntity = sceneEntity, let originEntity = originEntity, let character = skeletonEntity, let nextJointData = browserModel.nextJointData, let lastJointData = browserModel.lastJointData {
                if let nextModel = nextJointData.first, let lastModel = lastJointData.first{
                    let nextAnchorData = nextModel.a
                    let lastAnchorData = lastModel.a
                    let nextTranslation =  SIMD3<Float>(Float(nextAnchorData.x), Float(nextAnchorData.y), Float(nextAnchorData.z))
                    let lastTranslation =  SIMD3<Float>(Float(lastAnchorData.x), Float(lastAnchorData.y), Float(lastAnchorData.z))
                    let nextRotation = simd_quatf(real:Float(nextAnchorData.r), imag: SIMD3<Float>(Float(nextAnchorData.ix), Float(nextAnchorData.iy), Float(nextAnchorData.iz)))
                    let lastRotation = simd_quatf(real:Float(lastAnchorData.r), imag: SIMD3<Float>(Float(lastAnchorData.ix), Float(lastAnchorData.iy), Float(lastAnchorData.iz)))
                    
                    let percentage = Float(browserModel.frameCount) / Float(browserModel.skipFrames)
                    let anchorTranslation = lastTranslation + (nextTranslation - lastTranslation) * percentage
                    let anchorRotation = lastRotation + (nextRotation - lastRotation) * percentage
                                        
                    let transform = Transform(scale: SIMD3(1,1,1), rotation:anchorRotation, translation:anchorTranslation)
                    
                    characterAnchor.transform = transform
                    characterAnchor.transform.translation.y = characterOffset.y
                    

                }

                for index in 0..<nextJointData.count {
                    let nextModel = nextJointData[index]
                    let lastModel = lastJointData[index]
                    //print(data.d.name)
                    guard let index = character.jointNames.firstIndex(where: { jointName in
                        jointName.hasSuffix(nextModel.d.name)
                    }) else {
                        print("did not find index for \(nextModel)")
                        continue
                    }

                    let nextTranslation =  nextModel.translation
                    let lastTranslation =  lastModel.translation
                    let nextRotation = nextModel.orientation
                    let lastRotation = lastModel.orientation
                    
                    let percentage = Float(browserModel.frameCount) / Float(browserModel.skipFrames)
                    let jointTranslation = lastTranslation + (nextTranslation - lastTranslation) * percentage
                    let jointRotation = lastRotation + (nextRotation - lastRotation) * percentage
                    

                    character.jointTransforms[index] = Transform(scale: nextModel.scale, rotation:jointRotation, translation:jointTranslation )
                    print(nextModel.d.name)
                    
                    if nextModel.d.name == "left_hand_joint" {
                        
                        let leftHandTransform = nextModel.transform
                        
                        guard let leftForearmData = nextJointData.first(where: { jointData in
                            jointData.d.name == "left_forearm_joint"
                        })  else {
                            print("No left forearm")
                            return
                        }
                        
                        guard let leftArmData = nextJointData.first(where: { jointData in
                            jointData.d.name == "left_arm_joint"
                        })  else {
                            print("No left arm")
                            return
                        }
                        
                        guard let leftShoulderData = nextJointData.first(where: { jointData in
                            jointData.d.name == "left_shoulder_1_joint"
                        })  else {
                            print("No left shoulder")
                            return
                        }
                        
                        guard let spine7Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_7_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }
                        
                        guard let spine6Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_6_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }
                        
                        
                        guard let spine5Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_5_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }
                        
                        
                        guard let spine4Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_4_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }
                        
                        
                        guard let spine3Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_3_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }
                        
                        
                        guard let spine2Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_2_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }
                        
                        
                        
                        guard let spine1Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_1_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }
                        
                        guard let hipsData = nextJointData.first(where: { jointData in
                            jointData.d.name == "hips_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }
                        
                        let finalTransform = Transform(matrix: leftHandTransform.matrix * leftForearmData.transform.matrix * leftArmData.transform.matrix * leftShoulderData.transform.matrix * spine7Data.transform.matrix *
                                                       spine6Data.transform.matrix * spine5Data.transform.matrix * spine4Data.transform.matrix * spine3Data.transform.matrix * spine2Data.transform.matrix * spine1Data.transform.matrix * hipsData.transform.matrix)
                        
                        characterLeftHandAnchor.transform.translation = sessionManager.leftHandLocation.transform.translation
                        characterLeftHandAnchor.transform.rotation = characterAnchor.transform.rotation
                        guard var particleComponent = characterLeftHandAnchor.components[ParticleEmitterComponent.self] else {
                            return
                        }
                        
                                            
                        let characterWorldSpaceTransform = originEntity.convert(transform: characterAnchor.transform, to:characterLeftHandAnchor)
                        
                        particleComponent.mainEmitter.attractionCenter.x =  characterWorldSpaceTransform.translation.x - characterLeftHandAnchor.transform.translation.x
                        particleComponent.mainEmitter.attractionCenter.y = characterLeftHandAnchor.transform.translation.y - characterOffset.y
                        particleComponent.mainEmitter.attractionCenter.z = characterWorldSpaceTransform.translation.z - characterLeftHandAnchor.transform.translation.z
    
                        characterLeftHandAnchor.components[ParticleEmitterComponent.self] = particleComponent

                    }
                    
                    
                    if nextModel.d.name == "right_hand_joint" {
                        
                        let rightHandTransform = nextModel.transform
                        
                        guard let rightForearmData = nextJointData.first(where: { jointData in
                            jointData.d.name == "right_forearm_joint"
                        })  else {
                            print("No left forearm")
                            return
                        }

                        guard let rightArmData = nextJointData.first(where: { jointData in
                            jointData.d.name == "right_arm_joint"
                        })  else {
                            print("No left arm")
                            return
                        }

                        guard let rightShoulderData = nextJointData.first(where: { jointData in
                            jointData.d.name == "right_shoulder_1_joint"
                        })  else {
                            print("No left shoulder")
                            return
                        }
                        
                        guard let spine7Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_7_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }

                        guard let spine6Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_6_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }

                        
                        guard let spine5Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_5_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }

                        
                        guard let spine4Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_4_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }

                        
                        guard let spine3Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_3_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }

                        
                        guard let spine2Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_2_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }

                        
                        
                        guard let spine1Data = nextJointData.first(where: { jointData in
                            jointData.d.name == "spine_1_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }

                        guard let hipsData = nextJointData.first(where: { jointData in
                            jointData.d.name == "hips_joint"
                        })  else {
                            print("No spine 7")
                            return
                        }
                        
                        let finalTransform = Transform(matrix: rightHandTransform.matrix * rightForearmData.transform.matrix * rightArmData.transform.matrix * rightShoulderData.transform.matrix * spine7Data.transform.matrix *
                                                       spine6Data.transform.matrix * spine5Data.transform.matrix * spine4Data.transform.matrix * spine3Data.transform.matrix * spine2Data.transform.matrix * spine1Data.transform.matrix * hipsData.transform.matrix)
                       
                        characterRightHandAnchor.transform.translation = sessionManager.rightHandLocation.transform.translation
                        characterRightHandAnchor.transform.rotation = characterAnchor.transform.rotation
                        guard var particleComponent = characterRightHandAnchor.components[ParticleEmitterComponent.self] else {
                            return
                        }
                        
                                            
                        let characterWorldSpaceTransform = originEntity.convert(transform: characterAnchor.transform, to:characterRightHandAnchor)
                        
                        particleComponent.mainEmitter.attractionCenter.x =  characterWorldSpaceTransform.translation.x - characterRightHandAnchor.transform.translation.x
                        particleComponent.mainEmitter.attractionCenter.y = characterRightHandAnchor.transform.translation.y - characterOffset.y
                        particleComponent.mainEmitter.attractionCenter.z = characterWorldSpaceTransform.translation.z - characterRightHandAnchor.transform.translation.z
    
                        characterRightHandAnchor.components[ParticleEmitterComponent.self] = particleComponent

//                        print("Right world space translation : \(deviceWorldSpaceTransform)")
//                        print("Right hand attraction: \(particleComponent.mainEmitter.attractionCenter)")

                        characterRightHandAnchor.components[ParticleEmitterComponent.self] = particleComponent
                    }
                }
            }
//            print("Device location: \(sessionManager.deviceLocation.transform.translation)")
//            print("Right Hand location: \(characterRightHandAnchor.transform.translation)")
//            print("Left Hand location: \(characterLeftHandAnchor.transform.translation)")
        }
    }
}

#Preview {
    let model = NearbyServiceBrowserModel()
    return ImmersiveView(browserModel: model)
        .previewLayout(.sizeThatFits)
}
