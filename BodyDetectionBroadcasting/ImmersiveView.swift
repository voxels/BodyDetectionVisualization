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
    @Binding public var selectedFit:ModelFit?
    private let videoURLString = "http://192.168.8.179:1935/live/countryclub/playlist.m3u8?DVR"
    private let audioURLString = "http://192.168.8.179:8000/radio"
    @State private var sceneEntity:Entity?
    @State private var originEntity:Entity?
    @State private var innerSkeletonEntities = [String:ModelEntity]()
    @State private var outerSkeletonEntities = [String:ModelEntity]()
    @State private var partnerSkeletonIdentity:String?
    @State private var skeletonIdentityEntity: ModelEntity?
    @State private var gageDarkFitEntity: ModelEntity = ModelEntity()
    @State private var gageLightFitEntity: ModelEntity?
    @State private var jesseDarkFitEntity: ModelEntity?
    @State private var jesseLightFitEntity: ModelEntity?
    @State private var deanLightFitEntity:ModelEntity?
    @State private var deanDarkFitEntity:ModelEntity?
    @State private var characterOffset: SIMD3<Float> = [0, 0.94, 0] // Offset the character by one meter to the left
    @State private var characterOrder:[String] = [String]()
    @State private var characterAnchor = AnchorEntity()
    @State private var gageDarkFitAnchor = AnchorEntity()
    @State private var gageLightFitAnchor = AnchorEntity()
    @State private var jesseDarkFitAnchor = AnchorEntity()
    @State private var jesseLightFitAnchor = AnchorEntity()
    @State private var deanLightFitAnchor = AnchorEntity()
    @State private var deanDarkFitAnchor = AnchorEntity()
    
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
    
    @State private var isPaused:Bool = false
    
    var tap: some Gesture {
        LongPressGesture()
            .targetedToAnyEntity()
            .onEnded { event in
                isPaused.toggle()
                print("is paused \(isPaused)")
            }
    }
    
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
                
                if selectedFit == .GageDarkFit {
                    let gageDarkFitScene = try await Entity(named: "Scene_Gage_DarkFit", in: realityKitContentBundle)
                    print(gageDarkFitScene)
                    if let model = gageDarkFitScene.findEntity(named: "Skeleton_92") as? ModelEntity {
                        //print(model.name)
                        print("Found skeleton")
                        gageDarkFitEntity = model
                        scene.addChild(gageDarkFitAnchor)
                        gageDarkFitAnchor.addChild(model)
                    }
                }
                
                if selectedFit == .JesseDarkFit
                {
                    let jesseDarkFitScene = try await Entity(named: "Scene_Jesse_DarkFit", in: realityKitContentBundle)
                    print(jesseDarkFitScene)
                    if let model = jesseDarkFitScene.findEntity(named: "Skeleton_95") as? ModelEntity {
                        //print(model.name)
                        print("Found skeleton")
                        jesseDarkFitEntity = model
                        scene.addChild(jesseDarkFitAnchor)
                        jesseDarkFitAnchor.addChild(model)
                    }
                }
                
                if selectedFit == .JesseLightFit {
                    let jesseLightFitScene = try await Entity(named: "Scene_Jesse_LightFit", in: realityKitContentBundle)
                    print(jesseLightFitScene)
                    if let model = jesseLightFitScene.findEntity(named: "hips_joint_92") as? ModelEntity {
                        //print(model.name)
                        print("Found skeleton")
                        jesseLightFitEntity = model
                        scene.addChild(jesseLightFitAnchor)
                        jesseLightFitAnchor.addChild(model)
                    }
                }
                
                if selectedFit == .GageLightFit {
                    let gageLightFitScene = try await Entity(named: "Scene_Gage_LightFit", in: realityKitContentBundle)
                    print(gageLightFitScene)
                    if let model = gageLightFitScene.findEntity(named: "hips_joint_90") as? ModelEntity {
                        //print(model.name)
                        print("Found skeleton")
                        gageLightFitEntity = model
                        scene.addChild(gageLightFitAnchor)
                        gageLightFitAnchor.addChild(model)
                    }
                }
                
                if selectedFit == .DeanLightFit {
                    let deanLightFitScene = try await Entity(named: "Scene_Dean_LightFit", in: realityKitContentBundle)
                    print(deanLightFitScene)
                    if let model = deanLightFitScene.findEntity(named: "hips_joint_93") as? ModelEntity {
                        //print(model.name)
                        print("Found skeleton")
                        deanLightFitEntity = model
                        scene.addChild(deanLightFitAnchor)
                        deanLightFitAnchor.addChild(model)
                    }
                }
                
                if selectedFit == .DeanDarkFit {
                    let deanDarkFitScene = try await Entity(named: "Scene_Dean_DarkFit", in: realityKitContentBundle)
                    print(deanDarkFitScene)
                    if let model = deanDarkFitScene.findEntity(named: "hips_joint_93") as? ModelEntity {
                        //print(model.name)
                        print("Found skeleton")
                        deanDarkFitEntity = model
                        scene.addChild(deanDarkFitAnchor)
                        
                        deanDarkFitAnchor.addChild(model)
                    }
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
        }
        .onChange(of: isPaused, { oldValue, newValue in
            if newValue{
                browserModel.firstJointData = nil
            }
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
        .task {
            await sessionManager.run(function: updateParticles, withFrequency: 60)
        }
        .task(priority: .high) {
            await sessionManager.run(function: update, withFrequency: 60)
        }
        .task(priority: .high) {
            await sessionManager.run(function: updateAnchors, withFrequency: 30)
        }
        .task(priority: .high) {
            await sessionManager.run(function: updateDarkFitGage, withFrequency: 30)
        }
        .task(priority: .high, {
            await sessionManager.run(function: updateLightFitGage, withFrequency: 30)
        })
        .task(priority: .high, {
            await sessionManager.run(function: updateJesseLightFit, withFrequency: 30)
        })
        .task(priority: .high, {
            await sessionManager.run(function: updateJesseDarkFit, withFrequency: 30)
        })
        .task(priority: .high, {
            await sessionManager.run(function: updateDeanLightFit, withFrequency: 30)
        })
        .task(priority: .high, {
            await sessionManager.run(function: updateDeanDarkFit, withFrequency: 30)
        })
        .task(priority: .userInitiated) {
            await sessionManager.run(function: runAnimation, withFrequency:30)
        }
    }
    
    
    func updateJesseLightFit() {
        guard let jesseLightFitEntity = jesseLightFitEntity, let nextJointData = browserModel.nextJointData, !isPaused, selectedFit == .JesseLightFit else {
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
        jesseLightFitTransforms.removeAll()
    }
    
    
    func updateJesseDarkFit() {
        guard let jesseDarkFitEntity = jesseDarkFitEntity, let nextJointData = browserModel.nextJointData, !isPaused, selectedFit == .JesseDarkFit  else {
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
        

        jesseDarkFitTransforms.removeAll()
    }
    
    func updateDeanLightFit() {
        guard let deanLightFitEntity = deanLightFitEntity, let nextJointData = browserModel.nextJointData, !isPaused, selectedFit == .DeanLightFit else {
            return
        }
        
        var rawDeanLightFitTransforms = [Transform]()
        
        guard let _ = nextJointData.keys.first else {
            return
        }
        
        for key in [nextJointData.keys.first!] {
            print("Joints count: \(nextJointData[key]!.count) for \(key)")
            let jointData = nextJointData[key]!
            
            
            for index in 0..<deanLightFitEntity.jointTransforms.count {
                guard let nextModel = jointData.filter({ data in
                    return deanLightFitEntity.jointNames[index].hasSuffix(data.d.name)
                }).first else {
                    rawDeanLightFitTransforms.append(Transform(scale:deanLightFitEntity.jointTransforms[index].scale, rotation:deanLightFitEntity.jointTransforms[index].rotation, translation:deanLightFitEntity.jointTransforms[index].translation))
                    continue
                    
                }
                let nextTranslation =  nextModel.translation
                let nextRotation = nextModel.orientation
                
                
                rawDeanLightFitTransforms.append(Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation))
                
            }
            deanLightFitTransforms.append(rawDeanLightFitTransforms)
        }
        
        print("Dean light fit transforms count: \(deanLightFitTransforms.count)")
        if !deanLightFitTransforms.isEmpty {
            let firstIndex = 0
            let secondIndex = deanLightFitTransforms.count > 1 ? 1 : 0
            
            let animation = FromToByAnimation(jointNames: deanLightFitEntity.jointNames,name:UUID().uuidString, from:JointTransforms(deanLightFitEntity.jointTransforms), to:JointTransforms(deanLightFitTransforms[secondIndex]), by:JointTransforms(deanLightFitTransforms[firstIndex]), duration:browserModel.frameDuration * Double(browserModel.skipFrames), isAdditive: false, bindTarget: .jointTransforms, blendLayer:100, fillMode: .forwards )
            do {
                deanLightFitAnimationResource.append(try AnimationResource.generate(with: AnimationView(source: animation)))
            } catch {
                print(error)
            }
            
        }
        deanLightFitTransforms.removeAll()

    }
    
    func updateDeanDarkFit() {
        
        guard let deanDarkFitEntity = deanDarkFitEntity,     let nextJointData = browserModel.nextJointData, !isPaused, selectedFit == .DeanDarkFit else {
            return
        }
        
        var rawDeanDarkFitTransforms = [Transform]()
        
        guard let _ = nextJointData.keys.first else {
            return
        }
        
        for key in [nextJointData.keys.first!] {
            print("Joints count: \(nextJointData[key]!.count) for \(key)")
            let jointData = nextJointData[key]!
            
            for index in 0..<deanDarkFitEntity.jointTransforms.count {
                guard let nextModel = jointData.filter({ data in
                    return deanDarkFitEntity.jointNames[index].hasSuffix(data.d.name)
                }).first else {
                    rawDeanDarkFitTransforms.append(Transform(scale:deanDarkFitEntity.jointTransforms[index].scale, rotation:deanDarkFitEntity.jointTransforms[index].rotation, translation:deanDarkFitEntity.jointTransforms[index].translation))
                    continue
                    
                }
                let nextTranslation =  nextModel.translation
                let nextRotation = nextModel.orientation
                
                
                rawDeanDarkFitTransforms.append(Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation))
                
            }
            deanDarkFitTransforms.append(rawDeanDarkFitTransforms)
            
            print("Dean dark fit transforms count: \(deanDarkFitTransforms.count)")
            if !deanDarkFitTransforms.isEmpty {
                let firstIndex = 0
                let secondIndex = deanDarkFitTransforms.count > 1 ? 1 : 0
                
                let animation = FromToByAnimation(jointNames: deanDarkFitEntity.jointNames,name:UUID().uuidString, from:JointTransforms(deanDarkFitEntity.jointTransforms), to:JointTransforms(deanDarkFitTransforms[secondIndex]), by:JointTransforms(deanDarkFitTransforms[firstIndex]), duration:browserModel.frameDuration * Double(browserModel.skipFrames), isAdditive: false, bindTarget: .jointTransforms, blendLayer:0, fillMode: .forwards )
                do {
                    deanDarkFitAnimationResource.append(try AnimationResource.generate(with: AnimationView(source: animation)))
                } catch {
                    print(error)
                }
            }
            
        }
        deanDarkFitTransforms.removeAll()

    }
    
    func updateDarkFitGage() {
        guard  let nextJointData = browserModel.nextJointData, !isPaused, selectedFit == .GageDarkFit else {
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
        
        guard let gageLightFitEntity = gageLightFitEntity, let nextJointData = browserModel.nextJointData, !isPaused, selectedFit == .GageLightFit else {
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
    
    func updateKai() {
        
    }
    
    
    func updateAnchors() {
        guard let nextJointData = browserModel.nextJointData, let _ = nextJointData.keys.first, !isPaused else {
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
                
                if selectedFit == .GageDarkFit {
                    Task { @MainActor in
                        gageDarkFitAnchor.transform.translation.x = deviceOrigin.transform.translation.x + sin(Float.pi * 0) * radiusScale * nextTranslation.z + nextTranslation.x
                        gageDarkFitAnchor.transform.translation.y = characterOffset.y
                        gageDarkFitAnchor.transform.translation.z =
                        sessionManager.deviceOrigin.transform.translation.z + cos(Float.pi * 0) * radiusScale * nextTranslation.z
                        gageDarkFitAnchor.transform.rotation = transform.rotation
                    }
                }
                
                if selectedFit == .GageLightFit {
                    Task { @MainActor in
                        
                        gageLightFitAnchor.transform.translation.x =  deviceOrigin.transform.translation.x + sin(Float.pi * 0) * radiusScale * nextTranslation.z + nextTranslation.x
                        gageLightFitAnchor.transform.translation.y = characterOffset.y
                        gageLightFitAnchor.transform.translation.z =
                        deviceOrigin.transform.translation.z + cos(Float.pi * 0) * radiusScale * nextTranslation.z
                        gageLightFitAnchor.transform.rotation = transform.rotation
                    }
                }
                
                
                if selectedFit == .JesseLightFit {
                    Task { @MainActor in
                        jesseLightFitAnchor.transform.translation.x =  deviceOrigin.transform.translation.x + sin(Float.pi * 0) * radiusScale * nextTranslation.z + nextTranslation.x
                        jesseLightFitAnchor.transform.translation.y = characterOffset.y
                        jesseLightFitAnchor.transform.translation.z =  deviceOrigin.transform.translation.z +
                        cos(Float.pi * 0) * radiusScale * nextTranslation.z
                        jesseLightFitAnchor.transform.rotation = transform.rotation
                    }
                }
                
                if selectedFit == .JesseDarkFit {
                    Task { @MainActor in
                        jesseDarkFitAnchor.transform.translation.x =  deviceOrigin.transform.translation.x + sin(Float.pi * 0) * radiusScale * nextTranslation.z + nextTranslation.x
                        jesseDarkFitAnchor.transform.translation.y = characterOffset.y
                        jesseDarkFitAnchor.transform.translation.z =  deviceOrigin.transform.translation.z +
                        cos(Float.pi * 0) * radiusScale * nextTranslation.z
                        jesseDarkFitAnchor.transform.rotation = transform.rotation
                        
                    }
                }
                
                if selectedFit == .DeanLightFit {
                    Task { @MainActor in
                        
                        deanLightFitAnchor.transform.translation.x =  deviceOrigin.transform.translation.x + sin(Float.pi * 0) * radiusScale * nextTranslation.z + nextTranslation.x
                        deanLightFitAnchor.transform.translation.y = characterOffset.y
                        deanLightFitAnchor.transform.translation.z =  deviceOrigin.transform.translation.z +
                        cos(Float.pi * 0) * radiusScale * nextTranslation.z
                        deanLightFitAnchor.transform.rotation = transform.rotation
                    }
                }
                
                if selectedFit == .DeanDarkFit {
                    Task { @MainActor in
                        
                        deanDarkFitAnchor.transform.translation.x = deviceOrigin.transform.translation.x + sin(Float.pi * 0) * nextTranslation.z + nextTranslation.x
                        deanDarkFitAnchor.transform.translation.y = characterOffset.y
                        deanDarkFitAnchor.transform.translation.z = deviceOrigin.transform.translation.z +
                        cos(Float.pi * 0) * nextTranslation.z
                        deanDarkFitAnchor.transform.rotation = transform.rotation
                    }
                }
                //            print(nextModel.d.ident)
                //            print(nextModel.d.t)
            }
        }
    }
    
    @MainActor
    func updateParticles() {
        Task{@MainActor in
            guard let originEntity = originEntity else {
                return
            }
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
            
            characterRightHandAnchor.transform.translation = sessionManager.rightHandLocation.transform.translation
            characterRightHandAnchor.transform.rotation = characterAnchor.transform.rotation
            guard var particleComponent = characterRightHandAnchor.components[ParticleEmitterComponent.self] else {
                return
            }
            
            
            let rightCharacterWorldSpaceTransform = originEntity.convert(transform: characterAnchor.transform, to:characterRightHandAnchor)
            
            particleComponent.mainEmitter.attractionCenter.x =  rightCharacterWorldSpaceTransform.translation.x - characterRightHandAnchor.transform.translation.x
            particleComponent.mainEmitter.attractionCenter.y = characterRightHandAnchor.transform.translation.y - characterOffset.y
            particleComponent.mainEmitter.attractionCenter.z = rightCharacterWorldSpaceTransform.translation.z - characterRightHandAnchor.transform.translation.z
            
            characterRightHandAnchor.components[ParticleEmitterComponent.self] = particleComponent
            
            //                        print("Right world space translation : \(deviceWorldSpaceTransform)")
            //                        print("Right hand attraction: \(particleComponent.mainEmitter.attractionCenter)")
            
            characterRightHandAnchor.components[ParticleEmitterComponent.self] = particleComponent
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
                let gageDarkFitController =  gageDarkFitEntity.playAnimation(try AnimationResource.sequence(with: gageDarkFitAnimationResource))
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
            
            if !deanDarkFitAnimationResource.isEmpty {
                let deanDarkFitController =  deanDarkFitEntity?.playAnimation(try AnimationResource.sequence(with: deanDarkFitAnimationResource))
            }
            
            if !deanLightFitAnimationResource.isEmpty {
                let deanLightFitController =  deanLightFitEntity?.playAnimation(try AnimationResource.sequence(with: deanLightFitAnimationResource))
            }
            //                    let kaiDarkFitController =  kaiDarkFitEntity.playAnimation(try AnimationResource.sequence(with: kaiDarkFitAnimationResource))
            //                    kaiDarkFitController.resume()
            //
            //                    let kaiLightFitController =  kaiLightFitEntity.playAnimation(try AnimationResource.sequence(with: kaiLightFitAnimationResource))
            //                    kaiLightFitController.resume()
            gageDarkFitAnimationResource.removeAll()
            gageLightFitAnimationResource.removeAll()
            jesseDarkFitAnimationResource.removeAll()
            jesseLightFitAnimationResource.removeAll()
            deanLightFitAnimationResource.removeAll()
            deanDarkFitAnimationResource.removeAll()
        } catch {
            print(error)
        }
        print("finished playing animations")
    }
    
    func update() {
        if let _ = originEntity, browserModel.allData.count >= 1 {
            
            displayedFrameCount = min(browserModel.allData.count, 2)
            
            //            print("update \(browserModel.allData.count) frames left")
            //            print("displayed frame count: \(displayedFrameCount)")
            let allData = browserModel.allData.suffix(displayedFrameCount)
            
            for data in allData {
                if let next = browserModel.decodeFrame(data:data) {
                    //                        print("Finished decoding")
                    browserModel.nextJointData = next
                    //                        print("Finished skeleton update \(browserModel.nextJointData?.keys) \(browserModel.frameCount) \(browserModel.displayLinkTimestamp)")
                }
            }
        }
        
        browserModel.allData.removeAll()
    }
}


#Preview {
    let model = NearbyServiceBrowserModel()
    return ImmersiveView(browserModel: model, playerModel: PlayerModel(), selectedFit: .constant(.GageDarkFit))
        .previewLayout(.sizeThatFits)
}
