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
    @State private var gageDarkFitEntity: ModelEntity?
    @State private var gageLightFitEntity: ModelEntity?
    @State private var jesseDarkFitEntity: ModelEntity?
    @State private var jesseLightFitEntity: ModelEntity?
    @State private var deanLightFitEntity:ModelEntity?
    @State private var deanLightFitRumbaEntity:ModelEntity?
    @State private var characterOffset: SIMD3<Float> = [0, 0.94, 0] // Offset the character by one meter to the left
    @State private var characterOrder:[String] = [String]()
    @State private var characterAnchor = AnchorEntity()
    @State private var gageDarkFitAnchor = AnchorEntity()
    @State private var gageLightFitAnchor = AnchorEntity()
    @State private var jesseDarkFitAnchor = AnchorEntity()
    @State private var jesseLightFitAnchor = AnchorEntity()
    @State private var deanLightFitAnchor = AnchorEntity()
    @State private var deanLightFitRumbaAnchor = AnchorEntity()
    
    @State private var character = Entity()
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
    @State private var displayedFrameCount = 0
    
    @State private var gageDarkFitAnimationResource:[AnimationResource] = []
    @State private var gageLightFitAnimationResource:[AnimationResource] = []
    @State private var jesseDarkFitAnimationResource:[AnimationResource] = []
    @State private var jesseLightFitAnimationResource:[AnimationResource] = []
    @State private var deanDarkFitAnimationResource:[AnimationResource] = []
    @State private var deanLightFitAnimationResource:[AnimationResource] = []
    @State private var kaiDarkFitAnimationResource:[AnimationResource] = []
    @State private var kaiLightFitAnimationResource:[AnimationResource] = []
    
    
    @State private var gageDarkFitTransforms = [[Transform]]()
    @State private var gageLightFitTransforms = [[Transform]]()
    @State private  var jesseDarkFitTransforms = [[Transform]]()
    @State private var jesseLightFitTransforms = [[Transform]]()
    @State private var deanDarkFitTransforms = [[Transform]]()
    @State private var deanLightFitTransforms = [[Transform]]()
    @State private var kaiDarkFitTransforms = [[Transform]]()
    @State private var kaiLightFitTransforms = [[Transform]]()

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
                
                let gageDarkFitScene = try await Entity(named: "Scene_Gage_DarkFit", in: realityKitContentBundle)
                print(gageDarkFitScene)
                if let model = gageDarkFitScene.findEntity(named: "Skeleton_92") as? ModelEntity {
                    //print(model.name)
                    print("Found skeleton")
                    gageDarkFitEntity = model
                    scene.addChild(gageDarkFitAnchor)
                    gageDarkFitAnchor.addChild(model)
                }
                
                let jesseDarkFitScene = try await Entity(named: "Scene_Jesse_DarkFit", in: realityKitContentBundle)
                print(jesseDarkFitScene)
                if let model = jesseDarkFitScene.findEntity(named: "Skeleton_95") as? ModelEntity {
                    //print(model.name)
                    print("Found skeleton")
                    jesseDarkFitEntity = model
                    scene.addChild(jesseDarkFitAnchor)
                    jesseDarkFitAnchor.addChild(model)
                }
                
                let jesseLightFitScene = try await Entity(named: "Scene_Jesse_LightFit", in: realityKitContentBundle)
                print(jesseLightFitScene)
                if let model = jesseLightFitScene.findEntity(named: "Skeleton_94") as? ModelEntity {
                    //print(model.name)
                    print("Found skeleton")
                    jesseLightFitEntity = model
                    scene.addChild(jesseLightFitAnchor)
                    jesseLightFitAnchor.addChild(model)
                }
                
                let gageLightFitScene = try await Entity(named: "Scene_Gage_LightFit", in: realityKitContentBundle)
                print(gageLightFitScene)
                if let model = gageLightFitScene.findEntity(named: "Skeleton_94") as? ModelEntity {
                    //print(model.name)
                    print("Found skeleton")
                    gageLightFitEntity = model
                    scene.addChild(gageLightFitAnchor)
                    gageLightFitAnchor.addChild(model)
                }
                
                let deanLightFitScene = try await Entity(named: "Scene_Dean_LightFit", in: realityKitContentBundle)
                print(deanLightFitScene)
                if let model = deanLightFitScene.findEntity(named: "hips_joint_92") as? ModelEntity {
                    //print(model.name)
                    print("Found skeleton")
                    deanLightFitEntity = model
                    scene.addChild(deanLightFitAnchor)
                    deanLightFitAnchor.addChild(model)
                }
                
                let deanLightFitRumbaScene = try await Entity(named: "Scene_Dean_LightFit_Rumba", in: realityKitContentBundle)
                print(deanLightFitRumbaScene)
                if let model = deanLightFitRumbaScene.findEntity(named: "mixamorig_Hips") as? ModelEntity {
                    //print(model.name)
                    print("Found skeleton")
                    deanLightFitRumbaEntity = model
                    model.transform.scale *= 0.01
                    if let animation = model.availableAnimations.first {
                        model.playAnimation(animation.repeat())
                    }
                    scene.addChild(deanLightFitRumbaAnchor)
                    
                    deanLightFitRumbaAnchor.addChild(model)
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
                //scene.addChild(domeEntity!)
            } catch {
                print(error)
            }
        } update: { context in
            print("update scene\(browserModel.displayLinkTimestamp)")
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
        .task(priority: .high) {
            await sessionManager.run(function: update, withFrequency: 30)
        }
        .task(priority: .high) {
            await sessionManager.run(function: updateAnchors, withFrequency: 30)
        }
        .task(priority: .high) {
            await sessionManager.run(function: updateDarkFitGage, withFrequency: 30)
        }
        .task(priority: .userInitiated) {
            await sessionManager.run(function: runAnimation, withFrequency:60)
        }
        .onChange(of: browserModel.firstJointData) { oldValue, newValue in
            if newValue != nil {
                updateJesse()
                updateLightFitGage()
            }
        }
    }
    
    
    func updateJesse() {
        guard let jesseLightFitEntity = jesseLightFitEntity, let nextJointData = browserModel.firstJointData else {
            return
        }
        
        var rawJesseLightFitTransforms = [Transform]()

        guard let _ = nextJointData.keys.first else {
            return
        }
        
        for key in [nextJointData.keys.first!] {
            print("Joints count: \(nextJointData[key]!.count) for \(key)")
            let jointData = nextJointData[key]!
            
            
            for index in 0..<jesseLightFitEntity.jointTransforms.count {
                guard let nextModel = jointData.filter({ data in
                    return jesseLightFitEntity.jointNames[index].hasSuffix(data.d.name)
                }).first else {
                    rawJesseLightFitTransforms.append(Transform(scale:jesseLightFitEntity.jointTransforms[index].scale, rotation:jesseLightFitEntity.jointTransforms[index].rotation, translation:jesseLightFitEntity.jointTransforms[index].translation))
                    continue
                    
                }
                let nextTranslation =  nextModel.translation
                let nextRotation = nextModel.orientation
                
                
                rawJesseLightFitTransforms.append(Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation))
                
            }
            jesseLightFitTransforms.append(rawJesseLightFitTransforms)
        }
        
        print("Jesse light fit transforms count: \(jesseLightFitTransforms.count)")
        if !jesseLightFitTransforms.isEmpty {
            let firstIndex = 0
            let secondIndex = jesseLightFitTransforms.count > 1 ? 1 : 0
            
            let animation = FromToByAnimation(jointNames: jesseLightFitEntity.jointNames,name:UUID().uuidString, from:JointTransforms(jesseLightFitEntity.jointTransforms), to:JointTransforms(jesseLightFitTransforms[secondIndex]), by:JointTransforms(jesseLightFitTransforms[firstIndex]), duration:browserModel.frameDuration * Double(browserModel.skipFrames), isAdditive: false, bindTarget: .jointTransforms, blendLayer:100, fillMode: .forwards )
            do {
                jesseLightFitAnimationResource.append(try AnimationResource.generate(with: AnimationView(source: animation)))
            } catch {
                print(error)
            }
            
        }
        
        
        guard let jesseDarkFitEntity = jesseDarkFitEntity else {
            return
        }
        
        var rawJesseDarkFitTransforms = [Transform]()
        
        guard let _ = nextJointData.keys.first else {
            return
        }
        
        for key in [nextJointData.keys.first!] {
            print("Joints count: \(nextJointData[key]!.count) for \(key)")
            let jointData = nextJointData[key]!
            
            for index in 0..<jesseDarkFitEntity.jointTransforms.count {
                guard let nextModel = jointData.filter({ data in
                    return jesseDarkFitEntity.jointNames[index].hasSuffix(data.d.name)
                }).first else {
                    rawJesseDarkFitTransforms.append(Transform(scale:jesseDarkFitEntity.jointTransforms[index].scale, rotation:jesseDarkFitEntity.jointTransforms[index].rotation, translation:jesseDarkFitEntity.jointTransforms[index].translation))
                    continue
                    
                }
                let nextTranslation =  nextModel.translation
                let nextRotation = nextModel.orientation
                
                
                rawJesseDarkFitTransforms.append(Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation))
                
            }
            jesseDarkFitTransforms.append(rawJesseDarkFitTransforms)
            
            print("Jesse dark fit transforms count: \(jesseDarkFitTransforms.count)")
            if !jesseDarkFitTransforms.isEmpty {
                let firstIndex = 0
                let secondIndex = jesseDarkFitTransforms.count > 1 ? 1 : 0
                
                let animation = FromToByAnimation(jointNames: jesseDarkFitEntity.jointNames,name:UUID().uuidString, from:JointTransforms(jesseDarkFitEntity.jointTransforms), to:JointTransforms(jesseDarkFitTransforms[secondIndex]), by:JointTransforms(jesseDarkFitTransforms[firstIndex]), duration:browserModel.frameDuration * Double(browserModel.skipFrames), isAdditive: false, bindTarget: .jointTransforms, blendLayer:0, fillMode: .forwards )
                do {
                    jesseDarkFitAnimationResource.append(try AnimationResource.generate(with: AnimationView(source: animation)))
                } catch {
                    print(error)
                }
            }

        }
        
        jesseLightFitTransforms.removeAll()
        jesseDarkFitTransforms.removeAll()
    }
    
    func updateDarkFitGage() {
        guard let gageDarkFitEntity = gageDarkFitEntity, let nextJointData = browserModel.nextJointData else {
            return
        }
        var rawGageDarkFitTransforms = [Transform]()
        guard let _ = nextJointData.keys.first else {
            return
        }
        
        for key in [nextJointData.keys.first!] {
            print("Joints count: \(nextJointData[key]!.count) for \(key)")
            let jointData = nextJointData[key]!
            
            for index in 0..<gageDarkFitEntity.jointTransforms.count {
                guard let nextModel = jointData.first(where: { data in
                    return gageDarkFitEntity.jointNames[index].hasSuffix(data.d.name)
                }) else {
                    rawGageDarkFitTransforms.append(Transform(scale: gageDarkFitEntity.jointTransforms[index].scale, rotation:gageDarkFitEntity.jointTransforms[index].rotation, translation:gageDarkFitEntity.jointTransforms[index].translation))
                    continue
                }
                let nextTranslation =  nextModel.translation
                let nextRotation = nextModel.orientation
                
                
                rawGageDarkFitTransforms.append(Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation))
            }
            gageDarkFitTransforms.append(rawGageDarkFitTransforms)
        }
        
        print("Gage dark fit transforms count: \(gageDarkFitTransforms.count)")
        if !gageDarkFitTransforms.isEmpty {
            let firstIndex = 0
            let secondIndex = gageDarkFitTransforms.count > 1 ? 1 : 0
            let animation = FromToByAnimation(jointNames: gageDarkFitEntity.jointNames,name:UUID().uuidString, from:JointTransforms(gageDarkFitEntity.jointTransforms), to:JointTransforms(gageDarkFitTransforms[secondIndex]), by:JointTransforms(gageDarkFitTransforms[firstIndex]), duration:browserModel.frameDuration * Double(browserModel.skipFrames), isAdditive: false, bindTarget: .jointTransforms, blendLayer:0, fillMode: .forwards )
            do {
                gageDarkFitAnimationResource.append(try AnimationResource.generate(with: AnimationView(source: animation)))
            } catch {
                print(error)
            }
        }

        
        gageDarkFitTransforms.removeAll()
    }

    func updateLightFitGage() {
        
        guard let gageLightFitEntity = gageLightFitEntity, let nextJointData = browserModel.firstJointData else {
            return
        }
        
        var rawGageLightFitTransforms = [Transform]()
        guard let _ = nextJointData.keys.first else {
            return
        }
        
        for key in [nextJointData.keys.first!] {
            print("Joints count: \(nextJointData[key]!.count) for \(key)")
            let jointData = nextJointData[key]!
            
            
            for index in 0..<gageLightFitEntity.jointTransforms.count {
                guard let nextModel = jointData.filter({ data in
                    return gageLightFitEntity.jointNames[index].hasSuffix(data.d.name)
                }).first else {
                    rawGageLightFitTransforms.append(Transform(scale: gageLightFitEntity.jointTransforms[index].scale, rotation:gageLightFitEntity.jointTransforms[index].rotation, translation:gageLightFitEntity.jointTransforms[index].translation))
                    
                    continue
                }
                let nextTranslation =  nextModel.translation
                let nextRotation = nextModel.orientation
                
                
                rawGageLightFitTransforms.append(Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation))
            }
            gageLightFitTransforms.append(rawGageLightFitTransforms)
            
            print("Gage light fit transforms count: \(gageLightFitTransforms.count)")
            if !gageLightFitTransforms.isEmpty {
                let firstIndex = 0
                let secondIndex = gageLightFitTransforms.count > 1 ? 1 : 0
                 
                let animation = FromToByAnimation(jointNames: gageLightFitEntity.jointNames,name:UUID().uuidString, from:JointTransforms(gageLightFitEntity.jointTransforms), to:JointTransforms(gageLightFitTransforms[secondIndex]), by:JointTransforms(gageLightFitTransforms[firstIndex]), duration:browserModel.frameDuration * Double(browserModel.skipFrames),  isAdditive: false, bindTarget: .jointTransforms, blendLayer:0, fillMode: .forwards )
                do {
                    gageLightFitAnimationResource.append(try AnimationResource.generate(with: AnimationView(source: animation)))
                } catch {
                    print(error)
                }
            }
            
        }
        gageLightFitTransforms.removeAll()
    }
    func updateDean() {
        
    }
    
    func updateKai() {
        
    }
    
    @MainActor
    func updateAnchors() {
        guard let nextJointData = browserModel.nextJointData, let _ = nextJointData.keys.first else {
            return
        }
        
        for key in [nextJointData.keys.first!] {
            if let nextModel = nextJointData[key]!.first {
                if nextModel.d.a < 1.0 {
                    print("Not tracked \(nextModel.d.ident)")
                }
                
                let deviceOrigin = sessionManager.deviceOrigin
                
                let nextAnchorData = nextModel.a
                let nextTranslation =  SIMD3<Float>(Float(nextAnchorData.x), Float(nextAnchorData.y), Float(nextAnchorData.z))
                let nextRotation = simd_quatf(real:Float(nextAnchorData.r), imag: SIMD3<Float>(Float(nextAnchorData.ix), Float(nextAnchorData.iy), Float(nextAnchorData.iz)))
                
                let transform = Transform(scale: SIMD3(1,1,1), rotation:nextRotation, translation:nextTranslation)
                
                let radiusScale:Float = 0.85
                
                gageDarkFitAnchor.transform.translation.x = deviceOrigin.transform.translation.x + sin(Float.pi * 0) * radiusScale * nextTranslation.z + nextTranslation.x
                gageDarkFitAnchor.transform.translation.y = characterOffset.y
                gageDarkFitAnchor.transform.translation.z =
                sessionManager.deviceOrigin.transform.translation.z + cos(Float.pi * 0) * radiusScale * nextTranslation.z
                gageDarkFitAnchor.transform.rotation = transform.rotation
                
                
                jesseLightFitAnchor.transform.translation.x =  deviceOrigin.transform.translation.x + sin(Float.pi * 1 / 4) * radiusScale * nextTranslation.z + nextTranslation.x
                jesseLightFitAnchor.transform.translation.y = characterOffset.y
                jesseLightFitAnchor.transform.translation.z =  deviceOrigin.transform.translation.z +
                cos(Float.pi * 1 / 4) * radiusScale * nextTranslation.z
                jesseLightFitAnchor.transform.rotation = transform.rotation
                
                gageLightFitAnchor.transform.translation.x =  deviceOrigin.transform.translation.x + sin(Float.pi * 2 / 4) * radiusScale * nextTranslation.z + nextTranslation.x
                gageLightFitAnchor.transform.translation.y = characterOffset.y
                gageLightFitAnchor.transform.translation.z =
                deviceOrigin.transform.translation.z + cos(Float.pi * 2 / 4) * radiusScale * nextTranslation.z
                gageLightFitAnchor.transform.rotation = transform.rotation
                
                jesseDarkFitAnchor.transform.translation.x =  deviceOrigin.transform.translation.x + sin(Float.pi * 3 / 4) * radiusScale * nextTranslation.z + nextTranslation.x
                jesseDarkFitAnchor.transform.translation.y = characterOffset.y
                jesseDarkFitAnchor.transform.translation.z =  deviceOrigin.transform.translation.z +
                cos(Float.pi * 3 / 4) * radiusScale * nextTranslation.z
                jesseDarkFitAnchor.transform.rotation = transform.rotation
                
                deanLightFitAnchor.transform.translation.x =  deviceOrigin.transform.translation.x + sin(Float.pi * 4 / 4) * radiusScale * nextTranslation.z + nextTranslation.x
                deanLightFitAnchor.transform.translation.y = characterOffset.y
                deanLightFitAnchor.transform.translation.z =  deviceOrigin.transform.translation.z +
                cos(Float.pi * 4 / 4) * radiusScale * nextTranslation.z
                deanLightFitAnchor.transform.rotation = transform.rotation
                
                
                deanLightFitRumbaAnchor.transform.translation.x = deviceOrigin.transform.translation.x + sin(Float.pi * 5 / 4) * 1.5 * nextTranslation.z + nextTranslation.x
                deanLightFitRumbaAnchor.transform.translation.y = 0
                deanLightFitRumbaAnchor.transform.translation.z = deviceOrigin.transform.translation.z +
                cos(Float.pi * 5 / 4) * 1.5 * nextTranslation.z
                deanLightFitRumbaAnchor.transform.rotation = transform.rotation
                //            print(nextModel.d.ident)
                //            print(nextModel.d.t)
            }
        }
    }
    
    func updateFrame() {
        browserModel.frameCount += 1
    }
    
    func runAnimation() {
            do {
                print("Playing animation resources")
                
                if !gageDarkFitAnimationResource.isEmpty {
                    print(gageDarkFitAnimationResource.count)
                    let gageDarkFitController =  gageDarkFitEntity?.playAnimation(try AnimationResource.sequence(with: gageDarkFitAnimationResource))
                }

                if !gageLightFitAnimationResource.isEmpty {
                    let gageLightFitController =  gageLightFitEntity?.playAnimation(try AnimationResource.sequence(with: gageLightFitAnimationResource))
                }

                if !jesseDarkFitAnimationResource.isEmpty {
                    let jesseDarkFitController =  jesseDarkFitEntity?.playAnimation(try AnimationResource.sequence(with: jesseDarkFitAnimationResource))
                }

                if !jesseLightFitAnimationResource.isEmpty {
                    let jesseLightFitController =  jesseLightFitEntity?.playAnimation(try AnimationResource.sequence(with: jesseLightFitAnimationResource))
                }

                //                    let deanDarkFitController =  deanDarkFitEntity.playAnimation(try AnimationResource.sequence(with: deanDarkFitAnimationResource))
                //                    deanDarkFitController.resume()
                
                //                    let deanLightFitController =  deanLightFitEntity.playAnimation(try AnimationResource.sequence(with: deanLightFitAnimationResource))
                //                    deanLightFitController.resume()
                
                //                    let kaiDarkFitController =  kaiDarkFitEntity.playAnimation(try AnimationResource.sequence(with: kaiDarkFitAnimationResource))
                //                    kaiDarkFitController.resume()
                //
                //                    let kaiLightFitController =  kaiLightFitEntity.playAnimation(try AnimationResource.sequence(with: kaiLightFitAnimationResource))
                //                    kaiLightFitController.resume()
                gageDarkFitAnimationResource.removeAll()
                gageLightFitAnimationResource.removeAll()
                jesseDarkFitAnimationResource.removeAll()
                jesseLightFitAnimationResource.removeAll()
            } catch {
                print(error)
            }
        print("finished playing animations")
    }
    
    func update() {
        if let originEntity = originEntity, let gageDarkFitEntity = gageDarkFitEntity, let jesseDarkFitEntity = jesseDarkFitEntity, let gageLightFitEntity = gageLightFitEntity, let jesseLightFitEntity = jesseLightFitEntity, let deanLightFitEntity = deanLightFitEntity, browserModel.allData.count >= 2 {

            displayedFrameCount = min(browserModel.allData.count, 2)

            print("update \(browserModel.allData.count) frames left")
            print("displayed frame count: \(displayedFrameCount)")
            let allData = browserModel.allData.suffix(displayedFrameCount)

            for data in allData {
                if let next = browserModel.decodeFrame(data:data) {
                        print("Finished decoding")
                        browserModel.nextJointData = next
                        print("Finished skeleton update \(browserModel.nextJointData?.keys) \(browserModel.frameCount) \(browserModel.displayLinkTimestamp)")
                    }
                }
            }
            
            
            


                
                
                
                /*
                 
                 
                 if browserModel.jointDataHistory.count > 40 {
                 let nextJointData = browserModel.jointDataHistory[40]
                 Task { @MainActor in
                 for index in 0..<nextJointData.count {
                 let nextModel = nextJointData[index]
                 
                 let nextTranslation =  nextModel.translation
                 let nextRotation = nextModel.orientation
                 
                 guard let deanLightFitIndex = deanLightFitEntity.jointNames.firstIndex(where: { jointName in
                 jointName.hasSuffix(nextModel.d.name)
                 }) else {
                 if nextModel.d.name == "root" {
                 deanLightFitEntity.jointTransforms[0] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
                 }
                 continue
                 }
                 
                 deanLightFitEntity.jointTransforms[deanLightFitIndex] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
                 }
                 }
                 }
                 
                 //                    if browserModel.jointDataHistory.count > 300 {
                 //                        let nextJointData = browserModel.jointDataHistory[300]
                 //                        for index in 0..<nextJointData.count {
                 //                            let nextModel = nextJointData[index]
                 //
                 //                            let nextTranslation =  nextModel.translation
                 //                            let nextRotation = nextModel.orientation
                 //
                 //                            guard let deanLightFitIndex = deanLightFitEntity.jointNames.firstIndex(where: { jointName in
                 //                                jointName.hasSuffix(nextModel.d.name)
                 //                            }) else {
                 //                                if nextModel.d.name == "root" {
                 //                                    deanLightFitEntity.jointTransforms[0] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
                 //                                }
                 //                                continue
                 //                            }
                 //
                 //                            deanLightFitEntity.jointTransforms[deanLightFitIndex] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
                 //                        }
                 //                    }
                 
                 if browserModel.jointDataHistory.count > 60 {
                 //                        let nextJointData = browserModel.jointDataHistory[360]
                 //                        for index in 0..<nextJointData.count {
                 //                            let nextModel = nextJointData[index]
                 //
                 //                            let nextTranslation =  nextModel.translation
                 //                            let nextRotation = nextModel.orientation
                 //
                 //                            guard let deanLightFitIndex = deanLightFitEntity.jointNames.firstIndex(where: { jointName in
                 //                                jointName.hasSuffix(nextModel.d.name)
                 //                            }) else {
                 //                                if nextModel.d.name == "root" {
                 //                                    deanLightFitRumbaEntity.jointTransforms[0] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
                 //                                }
                 //                                continue
                 //                            }
                 //
                 //                            deanLightFitRumbaEntity.jointTransforms[deanLightFitIndex] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
                 //                        }
                 }
                 */
            browserModel.allData.removeAll()
    }
}


#Preview {
    let model = NearbyServiceBrowserModel()
    return ImmersiveView(browserModel: model, playerModel: PlayerModel())
        .previewLayout(.sizeThatFits)
}
