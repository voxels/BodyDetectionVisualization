//
//  ShareplayImmersiveView.swift
//  BodyTrackingVisualization
//
//  Created by Michael A Edgcumbe on 3/6/24.
//

import SwiftUI
import RealityKit
import RealityKitContent
import GroupActivities

struct ShareplayImmersiveView: View {
    @ObservedObject public var browserModel:ContentViewShareplayModel
    @StateObject private var sessionManager:SessionManager = SessionManager()
    @State private var playerModel = PlayerModel()
    private let videoURLString = "https://customer-02f18dl7ud0edmeq.cloudflarestream.com/eb980b10c52b699e5b544aceb9b610d9/manifest/video.m3u8"
    private let audioURLString = "https://streams.radiomast.io/295116c5-c102-44a8-b4ed-667dbfb3c4a7"
    @State private var sceneEntity:Entity?
    @State private var originEntity:Entity?
    @State private var skeletonEntity: ModelEntity?
    @State private var skeletonIdentityEntity: ModelEntity?
    @State private var ghostEntity: ModelEntity?
    @State private var domeEntity:ModelEntity?
    @State private var characterOffset: SIMD3<Float> = [0, 0.94, 0] // Offset the character by one meter to the left
    @State private var characterAnchor = Entity()
    @State private var characterLeftHandAnchor = Entity()
    @State private var characterRightHandAnchor = Entity()
    @State private var characterLeftFootAnchor = Entity()
    @State private var characterRightFootAnchor = Entity()
    @State private var processingMessage = false
    @State private var lastDecodedData:[String:JointData] = [String:JointData]()
    @State private var nextDecodedData:[String:JointData] = [String:JointData]()


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
                
                guard let jesseModel = scene.findEntity(named: "jesse") else {
                    return
                }
                
                if let model = jesseModel.findEntity(named: "biped_robot_root_91") as? ModelEntity {
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
                
                guard let alphaModel = scene.findEntity(named: "jesse") else {
                    return
                }
                
                if let model = alphaModel.findEntity(named:  "Mesh_0_001_93") as? ModelEntity {
                    //print(model.name)
                    print("Found ghost skeleton")
                    ghostEntity = model
                }
                
                guard let domeModel = scene.findEntity(named: "Sphere") as? ModelEntity else {
                    print("did not find dome")
                    return
                }
                domeEntity = domeModel
                let videoMaterial = VideoMaterial(avPlayer: playerModel.player)
                domeEntity?.model?.materials = [videoMaterial]
            } catch {
                print(error)
            }
        }
        .onDisappear(perform: {
            sessionManager.arkitSession.stop()
        })
        .task {
            do {
                playerModel.loadAudio(urlString: audioURLString)
                try await playerModel.loadVideo(URL(string:videoURLString)!, presentation: .fullWindow)
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
        .task {
            guard let messenger = browserModel.messenger else {
                if let groupSession = browserModel.groupSession {
                    browserModel.configureGroupSession(groupSession)
                }
                print("no messenger found")
                return
            }
            
            for await message in messenger.messages(of: Data.self) {
                let task = Task {
                    do {
                        let receivedItem = message.0
                        let decodedData = try JSONDecoder().decode(JointData.self, from: receivedItem)
                        if decodedData.d.name == "root" {
                            lastDecodedData = nextDecodedData
                            nextDecodedData = [String:JointData]()
                            nextDecodedData[decodedData.d.name] = decodedData
                            browserModel.handle(message:lastDecodedData)
                        } else {
                            nextDecodedData[decodedData.d.name] = decodedData
                            //print(decodedData.d.name)
                        }
                        lastDecodedData[decodedData.d.name] = decodedData
                        
                    } catch {
                        print(error)
                    }
                }
            }
        }
        .task {
            guard let journal = browserModel.journal else {
                if let groupSession = browserModel.groupSession {
                    browserModel.configureGroupSession(groupSession)
                }
                print("no journal found")
                return
            }
            print("found journal")
            for await attachments in journal.attachments {
                print("Found attachments")
                for attachment in attachments {
                    
                    let task = Task {
                        do {
                            let receivedItem = try await attachment.load(Data.self)
                            lastDecodedData = try JSONDecoder().decode([String:JointData].self, from: receivedItem)
                            browserModel.handle(message:lastDecodedData)
                            browserModel.attachmentHistory.append(attachment)
                            browserModel.jointAttachmentHistory.append(lastDecodedData)
                        } catch {
                            print(error)
                        }
                        return attachment
                    }
                    
                    let value = await task.value
                    print("finished with attachment")
                }
            }
            
            Task {
                for attachmentHistory in browserModel.attachmentHistory {
                    do {
                        try await journal.remove(attachment: attachmentHistory)
                        print("removed attachment history item")
                    } catch {
                        print(error)
                    }
                }
            }
        }
        .onChange(of: browserModel.lastFrameDisplayLinkTimestamp ) { oldValue, newValue in
            let nextJointData = browserModel.nextJointData
            if let sceneEntity = sceneEntity, let originEntity = originEntity, let character = skeletonEntity,  let lastJointData = browserModel.lastJointData {
                if let nextModel = nextJointData.first?.value, let lastModel = lastJointData.first?.value{
                    let nextAnchorData = nextModel.a
                    let lastAnchorData = lastModel.a
                    let nextTranslation =  SIMD3<Float>(Float(nextAnchorData.x), Float(nextAnchorData.y), Float(nextAnchorData.z))
                    let lastTranslation =  SIMD3<Float>(Float(lastAnchorData.x), Float(lastAnchorData.y), Float(lastAnchorData.z))
                    let nextRotation = simd_quatf(real:Float(nextAnchorData.r), imag: SIMD3<Float>(Float(nextAnchorData.ix), Float(nextAnchorData.iy), Float(nextAnchorData.iz)))
                    let lastRotation = simd_quatf(real:Float(lastAnchorData.r), imag: SIMD3<Float>(Float(lastAnchorData.ix), Float(lastAnchorData.iy), Float(lastAnchorData.iz)))
                    
                    let percentage = Float(browserModel.frameCount) / Float(browserModel.skipFrames)
                    let anchorTranslation = lastTranslation + (nextTranslation - lastTranslation) * percentage
                    let anchorRotation = lastRotation + (nextRotation - lastRotation) * percentage
                                        
                    let transform = Transform(scale: SIMD3(1,1,1), rotation:nextRotation, translation:anchorTranslation)
                    
                    withAnimation(Animation.linear(duration: browserModel.displayLink.duration * Double(browserModel.skipFrames)), {
                        characterAnchor.transform = transform
                        characterAnchor.transform.translation.y = characterOffset.y
                    })
                }

                for key in nextJointData.keys {
                    guard let nextModel = nextJointData[key], let lastModel = lastJointData[key],  let index = character.jointNames.firstIndex(where: { jointName in
                        jointName.hasSuffix(nextModel.d.name)
                    }) else {
                        print("did not find index for \(key)")
                        continue
                    }

                    let nextTranslation =  nextModel.translation
                    let lastTranslation =  lastModel.translation
                    let nextRotation = nextModel.orientation
                    let lastRotation = lastModel.orientation
                    
                    let percentage = Float(browserModel.frameCount) / Float(browserModel.skipFrames)
                    let anchorTranslation = lastTranslation + (nextTranslation - lastTranslation) * percentage
                    let anchorRotation = lastRotation + (nextRotation - lastRotation) * percentage

                    
                    withAnimation(Animation.linear(duration: browserModel.displayLink.duration * Double(browserModel.skipFrames)), {
                        character.jointTransforms[index] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
                        ghostEntity?.jointTransforms[index] = Transform(scale: nextModel.scale * SIMD3(1.0015,1.0015,1.0015), rotation:nextRotation, translation:nextTranslation)
                    })

                    
                    if nextModel.d.name == "left_foot_joint" {
                        
                        let leftFootTransform = nextModel.transform
                        
                        guard let leftHipData = nextJointData["left_upLeg_joint"] else {
                            print("No left hip")
                            continue
                        }

                        
                        guard let kneeData = nextJointData["left_leg_joint"] else {
                            print("No left knee")
                            continue
                        }

                        
                        
                        guard let hipsData = nextJointData["hips_joint"] else {
                            print("No hip")
                            continue
                        }
                        
                        
                        let finalTransform = Transform(matrix: leftFootTransform.matrix * kneeData.transform.matrix * leftHipData.transform.matrix * hipsData.transform.matrix)

                        let characterWorldSpaceTransform = originEntity.convert(transform: finalTransform, to:characterLeftFootAnchor)
                        
                        characterLeftFootAnchor.transform.translation = sessionManager.deviceLocation.transform.translation +        characterWorldSpaceTransform.translation - characterOffset
                        characterLeftFootAnchor.transform.rotation = sessionManager.deviceLocation.transform.rotation + characterWorldSpaceTransform.rotation

                        guard var particleComponent = characterLeftFootAnchor.components[ParticleEmitterComponent.self] else {
                            continue
                        }

                        
                        particleComponent.mainEmitter.attractionCenter.x =  characterWorldSpaceTransform.translation.x - characterLeftFootAnchor.transform.translation.x
                        particleComponent.mainEmitter.attractionCenter.y = characterLeftFootAnchor.transform.translation.y
                        particleComponent.mainEmitter.attractionCenter.z = characterWorldSpaceTransform.translation.z - characterLeftFootAnchor.transform.translation.z
    
                        characterLeftFootAnchor.components[ParticleEmitterComponent.self] = particleComponent
                    }
                    
                    if nextModel.d.name == "right_foot_joint" {
                        
                        let rightFootTransform = nextModel.transform
                        
                        guard let rightHipData = nextJointData["right_upLeg_joint"] else {
                            print("No right hip")
                            continue
                        }

                        
                        guard let kneeData = nextJointData["right_leg_joint"] else {
                            print("No right knee")
                            continue
                        }

                        
                        
                        guard let hipsData = nextJointData["hips_joint"] else {
                            print("No hip")
                            continue
                        }
                        
                        
                        let finalTransform = Transform(matrix: rightFootTransform.matrix * kneeData.transform.matrix * rightHipData.transform.matrix * hipsData.transform.matrix)

                        let characterWorldSpaceTransform = originEntity.convert(transform: finalTransform, to:characterRightFootAnchor)
                        
                        characterRightFootAnchor.transform.translation = sessionManager.deviceLocation.transform.translation + characterWorldSpaceTransform.translation - characterOffset
                        characterRightFootAnchor.transform.rotation = sessionManager.deviceLocation.transform.rotation + characterWorldSpaceTransform.rotation

                        guard var particleComponent = characterRightFootAnchor.components[ParticleEmitterComponent.self] else {
                            continue
                        }

                        
                        particleComponent.mainEmitter.attractionCenter.x =  characterWorldSpaceTransform.translation.x - characterRightFootAnchor.transform.translation.x
                        particleComponent.mainEmitter.attractionCenter.y = characterRightFootAnchor.transform.translation.y
                        particleComponent.mainEmitter.attractionCenter.z = characterWorldSpaceTransform.translation.z - characterRightFootAnchor.transform.translation.z
    
                        characterRightFootAnchor.components[ParticleEmitterComponent.self] = particleComponent
                    }
                    
                    if nextModel.d.name == "left_hand_joint" {
                        
                        let leftHandTransform = nextModel.transform
                        
                        guard let leftForearmData = nextJointData["left_forearm_joint"] else {
                            print("No left forearm")
                            continue
                        }
                        
                        guard let leftArmData = nextJointData["left_arm_joint"] else {
                            print("No left arm")
                            continue
                        }
                        
                        guard let leftShoulderData = nextJointData["left_shoulder_1_joint"] else {
                            print("No left shoulder")
                            continue
                        }
                        
                        guard let spine7Data = nextJointData["spine_7_joint"] else {
                            print("No spine 7")
                            continue
                        }
                        
                        guard let spine6Data = nextJointData["spine_6_joint"] else {
                            print("No spine 7")
                            continue
                        }
                        
                        
                        guard let spine5Data = nextJointData["spine_5_joint"] else {
                            print("No spine 7")
                            continue
                        }
                        
                        
                        guard let spine4Data = nextJointData["spine_4_joint"] else {
                            print("No spine 7")
                            continue
                        }
                        
                        
                        guard let spine3Data = nextJointData["spine_3_joint"] else {
                            print("No spine 7")
                            continue
                        }
                        
                        
                        guard let spine2Data = nextJointData["spine_2_joint"] else {
                            print("No spine 7")
                            continue
                        }
                        
                        guard let spine1Data = nextJointData["spine_1_joint"] else {
                            print("No spine 7")
                            continue
                        }
                        
                        guard let hipsData = nextJointData["hips_joint"] else {
                            print("No spine 7")
                            continue
                        }
                        
                        let finalTransform = Transform(matrix: leftHandTransform.matrix * leftForearmData.transform.matrix * leftArmData.transform.matrix * leftShoulderData.transform.matrix * spine7Data.transform.matrix *
                                                       spine6Data.transform.matrix * spine5Data.transform.matrix * spine4Data.transform.matrix * spine3Data.transform.matrix * spine2Data.transform.matrix * spine1Data.transform.matrix * hipsData.transform.matrix)
                        
                        characterLeftHandAnchor.transform.translation = sessionManager.leftHandLocation.transform.translation
                        characterLeftHandAnchor.transform.rotation = characterAnchor.transform.rotation
                        guard var particleComponent = characterLeftHandAnchor.components[ParticleEmitterComponent.self] else {
                            continue
                        }
                        
                                            
                        let characterWorldSpaceTransform = originEntity.convert(transform: characterAnchor.transform, to:characterLeftHandAnchor)
                        
                        particleComponent.mainEmitter.attractionCenter.x =  characterWorldSpaceTransform.translation.x - characterLeftHandAnchor.transform.translation.x
                        particleComponent.mainEmitter.attractionCenter.y = characterLeftHandAnchor.transform.translation.y
                        particleComponent.mainEmitter.attractionCenter.z = characterWorldSpaceTransform.translation.z - characterLeftHandAnchor.transform.translation.z
    
                        characterLeftHandAnchor.components[ParticleEmitterComponent.self] = particleComponent

                    }
                    
                    
                    if nextModel.d.name == "right_hand_joint" {
                        
                        let rightHandTransform = nextModel.transform
                        
                        guard let rightForearmData = nextJointData["right_forearm_joint"] else {
                            print("No left forearm")
                            continue
                        }

                        guard let rightArmData = nextJointData["right_arm_joint"] else {
                            print("No left arm")
                            continue
                        }

                        guard let rightShoulderData = nextJointData["right_shoulder_1_joint"] else {
                            print("No left shoulder")
                            continue
                        }
                        
                        guard let spine7Data = nextJointData["spine_7_joint"] else {
                            print("No spine 7")
                            continue
                        }

                        guard let spine6Data = nextJointData["spine_6_joint"] else {
                            print("No spine 7")
                            continue
                        }

                        
                        guard let spine5Data = nextJointData["spine_5_joint"] else {
                            print("No spine 7")
                            continue
                        }

                        
                        guard let spine4Data = nextJointData["spine_4_joint"] else {
                            print("No spine 7")
                            continue
                        }

                        
                        guard let spine3Data = nextJointData["spine_3_joint"] else {
                            print("No spine 7")
                            continue
                        }

                        
                        guard let spine2Data = nextJointData["spine_2_joint"] else {
                            print("No spine 7")
                            continue
                        }

                        
                        
                        guard let spine1Data = nextJointData["spine_1_joint"] else {
                            print("No spine 7")
                            continue
                        }

                        guard let hipsData = nextJointData["hips_joint"] else {
                            print("No spine 7")
                            continue
                        }
                        
                        let finalTransform = Transform(matrix: rightHandTransform.matrix * rightForearmData.transform.matrix * rightArmData.transform.matrix * rightShoulderData.transform.matrix * spine7Data.transform.matrix *
                                                       spine6Data.transform.matrix * spine5Data.transform.matrix * spine4Data.transform.matrix * spine3Data.transform.matrix * spine2Data.transform.matrix * spine1Data.transform.matrix * hipsData.transform.matrix)
                       
                        characterRightHandAnchor.transform.translation = sessionManager.rightHandLocation.transform.translation
                        characterRightHandAnchor.transform.rotation = characterAnchor.transform.rotation
                        guard var particleComponent = characterRightHandAnchor.components[ParticleEmitterComponent.self] else {
                            continue
                        }
                        
                                            
                        let characterWorldSpaceTransform = originEntity.convert(transform: characterAnchor.transform, to:characterRightHandAnchor)
                        
                        particleComponent.mainEmitter.attractionCenter.x =  characterWorldSpaceTransform.translation.x - characterRightHandAnchor.transform.translation.x
                        particleComponent.mainEmitter.attractionCenter.y = characterRightHandAnchor.transform.translation.y
                        particleComponent.mainEmitter.attractionCenter.z = characterWorldSpaceTransform.translation.z - characterRightHandAnchor.transform.translation.z
    
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
    ShareplayImmersiveView(browserModel: ContentViewShareplayModel())
}
