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
    public var playerModel:PlayerModel
    @StateObject private var sessionManager:SessionManager = SessionManager()
    private let videoURLString = "http://192.168.8.179:1935/live/countryclub/playlist.m3u8?DVR"
    private let audioURLString = "http://192.168.8.179:8000/radio"
    @State private var sceneEntity:Entity?
    @State private var originEntity:Entity?
    @State private var innerSkeletonEntities = [String:ModelEntity]()
    @State private var outerSkeletonEntities = [String:ModelEntity]()
    @State private var partnerSkeletonIdentity:String?
    @State private var skeletonIdentityEntity: ModelEntity?
    @State private var characterOffset: SIMD3<Float> = [0, 0.94, 0] // Offset the character by one meter to the left
    @State private var characterOrder:[String] = [String]()
    @State private var characterAnchor:AnchorEntity?
    @State private var character = Entity()
    @State private var characterAnchors = [String:Entity]()
    @State private var characterAnchorIdentityEntity: Entity?
    @State private var characterLeftHandAnchor = Entity()
    @State private var characterRightHandAnchor = Entity()
    @State private var characterLeftFootAnchor = Entity()
    @State private var characterRightFootAnchor = Entity()
    @State private var processingMessage = false
    @State private var lastDecodedData:[String:SkeletonJointData] = [String:SkeletonJointData]()
    @State private var nextDecodedData:[String:SkeletonJointData] = [String:SkeletonJointData]()
    @State private var domeEntity:ModelEntity?
    @State private var floorMaterial:VideoMaterial?
    @State private var floorModel:ModelEntity?
    
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
                
                scene.addChild(sessionManager.meshEntity)
                
                let jesseModel = try await Entity(named: "Scene_Jesse", in: realityKitContentBundle)
                print(jesseModel)
                if let model = jesseModel.findEntity(named: "Skeleton_001_92") as? ModelEntity {
                    //print(model.name)
                    print("Found skeleton")
                    skeletonIdentityEntity = model
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
                
                guard let sphereModel = scene.findEntity(named: "Sphere") as? ModelEntity else {
                    print("did not find dome")
                    return
                }
                domeEntity = sphereModel
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
        .task(priority: .low) {
            await sessionManager.processReconstructionUpdates()
        }
        .task(priority: .userInitiated, {
            guard let messenger = browserModel.messenger else {
                if let groupSession = browserModel.groupSession {
                    browserModel.configureGroupSession(groupSession)
                }
                print("no messenger found")
                return
            }
            
            for await message in messenger.messages(of: JointData.self) {
                let receivedItem = message.0
                browserModel.handle(message:receivedItem)
            }
        })
        /*
        .task(priority: .userInitiated, {
            guard let journal = browserModel.journal else {
                if let groupSession = browserModel.groupSession {
                    browserModel.configureGroupSession(groupSession)
                    playerModel.player.playbackCoordinator.coordinateWithSession(groupSession)
                    playerModel.audioPlayer.playbackCoordinator.coordinateWithSession(groupSession)
                    Task { @MainActor in
                        do {
                            playerModel.loadAudio(urlString: audioURLString)
                            try await playerModel.loadVideo(URL(string:videoURLString)!, presentation: .fullWindow)
                        } catch {
                            print(error)
                        }
                    }
                }
                print("no journal found")
                return
            }
            print("found journal")
            for await attachments in journal.attachments {
                print("Found attachments")
                for attachment in attachments {
                    do {
                        let receivedItem = try await attachment.load(JointData.self)
                        browserModel.handle(message:receivedItem)
                        browserModel.attachmentHistory.append(attachment.id)
                    } catch {
                        print(error)
                    }
                }
            }
        })
         */
        .task {
            if let groupSession = browserModel.groupSession {
                playerModel.player.playbackCoordinator.coordinateWithSession(groupSession)
                playerModel.audioPlayer.playbackCoordinator.coordinateWithSession(groupSession)
                Task { @MainActor in
                    do {
                        playerModel.loadAudio(urlString: audioURLString)
                        try await playerModel.loadVideo(URL(string:videoURLString)!, presentation: .fullWindow)
                    } catch {
                        print(error)
                    }
                }
            }
        }
        .onChange(of: browserModel.lastFrameDisplayLinkTimestamp ) { oldValue, newValue in
            let nextSkeletonData = browserModel.nextSkeletonData
            if let sceneEntity = sceneEntity, let originEntity = originEntity, let skeletonIdentityEntity = skeletonIdentityEntity, let lastCharacter = characterOrder.last, let nextJointData = nextSkeletonData[lastCharacter] {
                    if let nextModel = nextJointData.jointData.first {
                        let nextAnchorData = nextModel.value.a
                        let nextTranslation =  SIMD3<Float>(Float(nextAnchorData.x), Float(nextAnchorData.y), Float(nextAnchorData.z))
                        let nextRotation = simd_quatf(real:Float(nextAnchorData.r), imag: SIMD3<Float>(Float(nextAnchorData.ix), Float(nextAnchorData.iy), Float(nextAnchorData.iz)))
                        let transform = Transform(scale: SIMD3(1,1,1), rotation:nextRotation, translation:nextTranslation)
                        
                        if let anchor = characterAnchors[nextJointData.ident] {
                            anchor.transform = transform
                            anchor.transform.translation.y = characterOffset.y
                        } else {
                            let characterAnchor = Entity()
                            characterAnchor.transform = transform
                            characterAnchor.transform.translation.y = characterOffset.y
                            characterAnchors[nextJointData.ident] = characterAnchor
                            sceneEntity.addChild(characterAnchor)
                        }
                        
//                        for lost in nextModel.value.l {
//                            if let anchor = characterAnchors[lost] {
//                                anchor.removeFromParent()
//                            }
//                            characterAnchors.removeValue(forKey: lost)
//                            print("Removed character \(lost)")
//                        }
                    }
                                        
                    for nextModel in nextJointData.jointData.values {
                        let nextTranslation =  nextModel.translation
                        let nextRotation = nextModel.orientation
                        
                        if let innerCharacter = innerSkeletonEntities[lastCharacter], /*let outerCharacter = outerSkeletonEntities[key],*/ let index = innerCharacter.jointNames.firstIndex(where: { jointName in
                            jointName.hasSuffix(nextModel.d.name)
                        }) {
                            innerCharacter.jointTransforms[index] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
//                            outerCharacter.jointTransforms[index] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
                        } else {
                            for key in innerSkeletonEntities.keys {
                                let value = innerSkeletonEntities[key]!
                                value.removeFromParent()
                            }
                            
                            let innerCharacter = skeletonIdentityEntity.clone(recursive: true)
//                            let outerCharacter = skeletonIdentityEntity.clone(recursive: true)
                            if let index = innerCharacter.jointNames.firstIndex(where: { jointName in
                                                   jointName.hasSuffix(nextModel.d.name)
                            }) {
                                innerCharacter.name = lastCharacter
//                                outerCharacter.name = key
                                innerCharacter.jointTransforms[index] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
//                                outerCharacter.jointTransforms[index] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
                            }
                            innerSkeletonEntities[lastCharacter] = innerCharacter
//                            outerSkeletonEntities[key] = outerCharacter
                            
                            if let anchor = characterAnchors[nextJointData.ident], !characterOrder.contains(nextJointData.ident) {
                                anchor.addChild(innerCharacter)
//                                anchor.addChild(outerCharacter)
                                print("adding character \(nextJointData.ident)")
                                characterOrder.append(nextJointData.ident)
                            } else if let anchor = characterAnchors[nextJointData.ident], characterOrder.contains(nextJointData.ident) {
                                print("found existing character")
                            }
                        }
                        
                        
//                        partnerSkeletonIdentity = nil
//                        var minDistance = Float.infinity
//                        
//                        for value in innerSkeletonEntities.values {
//                            let distanceVector = value.position(relativeTo: nil) - sessionManager.deviceLocation.position(relativeTo: nil)
//                            let distance = distanceVector.x * distanceVector.x + distanceVector.z + distanceVector.z
//                            if distance < minDistance {
//                                minDistance = distance
//                                partnerSkeletonIdentity = value.name
//                            }
//                        }
                        
                        if let lastCharacter = characterOrder.last, let characterAnchor = characterAnchors[lastCharacter] {
                            if nextModel.d.name == "left_foot_joint" {
                                
                                let leftFootTransform = nextModel.transform
                                
                                guard let leftHipData = nextJointData.jointData["left_upLeg_joint"] else {
                                    print("No left hip")
                                    continue
                                }
                                
                                
                                guard let kneeData = nextJointData.jointData["left_leg_joint"] else {
                                    print("No left knee")
                                    continue
                                }
                                
                                
                                
                                guard let hipsData = nextJointData.jointData["hips_joint"] else {
                                    print("No hip")
                                    continue
                                }
                                
                                
                                let finalTransform = Transform(matrix: leftFootTransform.matrix * kneeData.transform.matrix * leftHipData.transform.matrix * hipsData.transform.matrix)
                                
                                let characterWorldSpaceTransform = originEntity.convert(transform: finalTransform, to:characterLeftFootAnchor)
                                
                                characterLeftFootAnchor.transform.translation = sessionManager.deviceLocation.transform.translation + characterWorldSpaceTransform.translation - characterOffset
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
                                
                                guard let rightHipData = nextJointData.jointData["right_upLeg_joint"] else {
                                    print("No right hip")
                                    continue
                                }
                                
                                guard let kneeData = nextJointData.jointData["right_leg_joint"] else {
                                    print("No right knee")
                                    continue
                                }
                                
                                
                                
                                guard let hipsData = nextJointData.jointData["hips_joint"] else {
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
                                
                                guard let leftForearmData = nextJointData.jointData["left_forearm_joint"] else {
                                    print("No left forearm")
                                    continue
                                }
                                
                                guard let leftArmData = nextJointData.jointData["left_arm_joint"] else {
                                    print("No left arm")
                                    continue
                                }
                                
                                guard let leftShoulderData = nextJointData.jointData["left_shoulder_1_joint"] else {
                                    print("No left shoulder")
                                    continue
                                }
                                
                                guard let spine7Data = nextJointData.jointData["spine_7_joint"] else {
                                    print("No spine 7")
                                    continue
                                }
                                
                                guard let spine6Data = nextJointData.jointData["spine_6_joint"] else {
                                    print("No spine 6")
                                    continue
                                }
                                
                                
                                guard let spine5Data = nextJointData.jointData["spine_5_joint"] else {
                                    print("No spine 5")
                                    continue
                                }
                                
                                
                                guard let spine4Data = nextJointData.jointData["spine_4_joint"] else {
                                    print("No spine 4")
                                    continue
                                }
                                
                                
                                guard let spine3Data = nextJointData.jointData["spine_3_joint"] else {
                                    print("No spine 3")
                                    continue
                                }
                                
                                
                                guard let spine2Data = nextJointData.jointData["spine_2_joint"] else {
                                    print("No spine 2")
                                    continue
                                }
                                
                                guard let spine1Data = nextJointData.jointData["spine_1_joint"] else {
                                    print("No spine 1")
                                    continue
                                }
                                
                                guard let hipsData = nextJointData.jointData["hips_joint"] else {
                                    print("No hips")
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
                                particleComponent.mainEmitter.attractionCenter.y = characterLeftHandAnchor.transform.translation.y - characterOffset.y
                                particleComponent.mainEmitter.attractionCenter.z = characterWorldSpaceTransform.translation.z - characterLeftHandAnchor.transform.translation.z
                                
                                characterLeftHandAnchor.components[ParticleEmitterComponent.self] = particleComponent
                                
                            }
                            
                            
                            if nextModel.d.name == "right_hand_joint" {
                                
                                let rightHandTransform = nextModel.transform
                                
                                guard let rightForearmData = nextJointData.jointData["right_forearm_joint"] else {
                                    print("No left forearm")
                                    continue
                                }
                                
                                guard let rightArmData = nextJointData.jointData["right_arm_joint"] else {
                                    print("No left arm")
                                    continue
                                }
                                
                                guard let rightShoulderData = nextJointData.jointData["right_shoulder_1_joint"] else {
                                    print("No left shoulder")
                                    continue
                                }
                                
                                guard let spine7Data = nextJointData.jointData["spine_7_joint"] else {
                                    print("No spine 7")
                                    continue
                                }
                                
                                guard let spine6Data = nextJointData.jointData["spine_6_joint"] else {
                                    print("No spine 6")
                                    continue
                                }
                                
                                
                                guard let spine5Data = nextJointData.jointData["spine_5_joint"] else {
                                    print("No spine 5")
                                    continue
                                }
                                
                                
                                guard let spine4Data = nextJointData.jointData["spine_4_joint"] else {
                                    print("No spine 4")
                                    continue
                                }
                                
                                
                                guard let spine3Data = nextJointData.jointData["spine_3_joint"] else {
                                    print("No spine 3")
                                    continue
                                }
                                
                                
                                guard let spine2Data = nextJointData.jointData["spine_2_joint"] else {
                                    print("No spine 2")
                                    continue
                                }
                                
                                
                                
                                guard let spine1Data = nextJointData.jointData["spine_1_joint"] else {
                                    print("No spine 1")
                                    continue
                                }
                                
                                guard let hipsData = nextJointData.jointData["hips_joint"] else {
                                    print("No spine hips")
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
                                particleComponent.mainEmitter.attractionCenter.y = characterRightHandAnchor.transform.translation.y - characterOffset.y
                                particleComponent.mainEmitter.attractionCenter.z = characterWorldSpaceTransform.translation.z - characterRightHandAnchor.transform.translation.z
                                
                                characterRightHandAnchor.components[ParticleEmitterComponent.self] = particleComponent
                            }
                        }
                    }
                }
        }
    }
}

#Preview {
    ShareplayImmersiveView(browserModel: ContentViewShareplayModel(), playerModel: PlayerModel())
}
