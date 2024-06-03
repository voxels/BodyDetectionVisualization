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
    @ObservedObject var browserModel: NearbyServiceBrowserModel
    public var playerModel: PlayerModel
    @StateObject private var sessionManager: SessionManager = SessionManager()
    @Binding public var selectedFit: ModelFit?
    
    private let videoURLString = "http://192.168.8.179:1935/live/countryclub/playlist.m3u8?DVR"
    private let audioURLString = "http://192.168.8.179:8000/radio"
    
    @State private var characterOffset: SIMD3<Float> = [0, 0.94, 0]
    
    @State private var isPaused: Bool = false
    
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
            await loadInitialContent(in: content)
        }
        .task {
            browserModel.fitSelected = selectedFit != nil
            Task {
                await selectFit()
            }
        }
        .onChange(of: browserModel.frameCount, { oldValue, newValue in
            updateEntities()
        })
        .onChange(of: selectedFit) { oldValue, newValue in
            browserModel.fitSelected = newValue != nil
            if browserModel.fitSelected {
                Task {
                    await selectFit()
                }
            }
        }
        .onChange(of: isPaused) { oldValue, newValue in
            if newValue {
                browserModel.firstJointData = nil
            }
        }
        .task {
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
    }
    
    @MainActor
    private func loadInitialContent(in content: RealityViewContent) async {
        do {
            let scene = try await Entity(named: "Immersive", in: realityKitContentBundle)
            browserModel.sceneEntity = scene
            browserModel.originEntity = Entity()
            browserModel.originEntity?.position = SIMD3.zero
            content.add(scene)
            scene.addChild(browserModel.characterAnchor)
                        
            setupHandAndFootAnchors(in: scene)
            
            scene.addChild(sessionManager.deviceLocation)
            scene.addChild(sessionManager.leftHandLocation)
            scene.addChild(sessionManager.rightHandLocation)
            
            setupDomeEntity(in: scene)
        } catch {
            print(error)
        }
    }
    
    private func selectFit() async {
        //            scene.addChild(sessionManager.meshEntity)
        
        removeAnchorChildren(anchor:browserModel.characterAnchor)
        
        if selectedFit == .GageDarkFit {
            await addFitEntity(named: "Scene_Gage_DarkFit", anchor: browserModel.characterAnchor)
        }
        if selectedFit == .JesseDarkFit {
            await addFitEntity(named: "Scene_Jesse_DarkFit", anchor: browserModel.characterAnchor)
        }
        if selectedFit == .JesseLightFit {
            await addFitEntity(named: "Scene_Jesse_LightFit", anchor: browserModel.characterAnchor)
        }
        if selectedFit == .GageLightFit {
            await addFitEntity(named: "Scene_Gage_LightFit", anchor: browserModel.characterAnchor)
        }
        if selectedFit == .DeanLightFit {
            await addFitEntity(named: "Scene_Dean_LightFit", anchor: browserModel.characterAnchor)
        }
        if selectedFit == .DeanDarkFit {
            await addFitEntity(named: "Scene_Dean_DarkFit", anchor: browserModel.characterAnchor)
        }

    }
    
    @MainActor
    private func removeAnchorChildren(anchor: AnchorEntity) {
        if !anchor.children.isEmpty {
            for child in anchor.children {
                child.removeFromParent()
            }
        }
    }
    
    private func addFitEntity(named entityName: String, anchor: AnchorEntity) async {
        do {
            let fitScene = try await Entity(named: entityName, in: realityKitContentBundle)
            print(fitScene)
            if let model = fitScene.findEntity(named: "hips_joint_90") as? ModelEntity {
                print("Found skeleton")
                anchor.addChild(fitScene)
                await MainActor.run {
                    browserModel.skeletonIdentityEntity = model
                }
            }
        } catch {
            print("Error loading entity: \(entityName)")
        }
    }
    
    @MainActor
    private func setupHandAndFootAnchors(in scene: Entity) {
        if let anchor = scene.findEntity(named: "handAnchor_left") {
            print("Found left hand anchor")
            browserModel.characterLeftHandAnchor = anchor
        }
        if let anchor = scene.findEntity(named: "handAnchor_right") {
            print("Found right hand anchor")
            browserModel.characterRightHandAnchor = anchor
        }
        if let anchor = scene.findEntity(named: "footAnchor_left") {
            print("Found left foot anchor")
            browserModel.characterLeftFootAnchor = anchor
        }
        if let anchor = scene.findEntity(named: "footAnchor_right") {
            print("Found right foot anchor")
            browserModel.characterRightFootAnchor = anchor
        }
    }
    
    @MainActor
    private func setupDomeEntity(in scene: Entity) {
        guard let sphereModel = scene.findEntity(named: "Sphere") as? ModelEntity else {
            print("did not find dome")
            return
        }
        browserModel.domeEntity = sphereModel
        // let videoMaterial = VideoMaterial(avPlayer: playerModel.player)
        // domeEntity?.model?.materials = [videoMaterial]
        // scene.addChild(domeEntity
        
        // let videoMaterial = VideoMaterial(avPlayer: playerModel.player)
        // domeEntity?.model?.materials = [videoMaterial]
        // scene.addChild(domeEntity)
    }
    
    func updateEntities() {
        if !browserModel.fitSelected {
            return
        }
        
        browserModel.cancelCurrentUpdateTask()
        
        browserModel.updateTask = Task {
            await updateAnchors()
            await updateFit()
            updateParticles()
            browserModel.updateTask = nil
        }
    }
    
    
    func updateFit() async {
        guard let fitEntity = browserModel.skeletonIdentityEntity, let nextJointData = browserModel.nextJointData,  !isPaused else {
            return
        }
        
        var rawTransforms = Array(repeating: Transform(), count: fitEntity.jointNames.count)
        
        guard let _ = nextJointData.keys.first else {
            return
        }
        
        for key in [nextJointData.keys.first!] {
                        print("Joints count: \(nextJointData[key]!.count) for \(key)")
            let jointData = nextJointData[key]!
            //            print(jointData.count)
            for joint in jointData {
                //                print(joint.d.i)
                //                print(joint.d.name)
                guard let index = fitEntity.jointNames.firstIndex(where: { data in
                    data.hasSuffix(joint.d.name)
                }) else {
                    //                    print("Missing joint: \(joint.d.name)")
                    continue
                }
                
                let nextModel = joint
                //                print(index)
                //                print(jesseLightFitEntity.jointNames[index])
                //                print()
                
                let nextTranslation =  nextModel.translation
                let nextRotation = nextModel.orientation
                
                rawTransforms[index] = Transform(scale: nextModel.scale, rotation:nextRotation, translation:nextTranslation)
            }
            
            await MainActor.run {
                withAnimation {
                    fitEntity.jointTransforms = rawTransforms
                }
//                let animation = FromToByAnimation(jointNames:fitEntity.jointNames,name:UUID().uuidString,  to:JointTransforms(rawTransforms),  duration:browserModel.frameDuration, isAdditive: false, bindTarget: .jointTransforms, blendLayer:0, fillMode: .forwards )
//                do {
//                    fitEntity.playAnimation(try AnimationResource.generate(with: animation), transitionDuration: browserModel.frameDuration / 2)
//                    
//                } catch {
//                    print(error)
//                }
            }
        }
    }
    
    @MainActor
    func updateAnchors() async {
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
                
                let radiusScale:Float = 0.75
                let rotationAngle:Float = 0
                
                browserModel.characterAnchor.transform.translation.x = deviceOrigin.transform.translation.x + sin(Float.pi * rotationAngle) * radiusScale * nextTranslation.z + nextTranslation.x
                browserModel.characterAnchor.transform.translation.y = characterOffset.y
                browserModel.characterAnchor.transform.translation.z =
                sessionManager.deviceOrigin.transform.translation.z + cos(Float.pi * rotationAngle) * radiusScale * nextTranslation.z
                browserModel.characterAnchor.transform.rotation = transform.rotation
            }
        }
    }
    
    @MainActor
    func updateParticles() {
        guard let originEntity = browserModel.originEntity  else {
            return
        }
        
        let leftHandLocation = sessionManager.leftHandLocation
        let rightHandLocation = sessionManager.rightHandLocation
        let anchor = browserModel.characterAnchor
        
        browserModel.characterLeftHandAnchor?.transform.translation = leftHandLocation.transform.translation
        browserModel.characterLeftHandAnchor?.transform.rotation = anchor.transform.rotation
        guard var particleComponent = browserModel.characterLeftHandAnchor?.components[ParticleEmitterComponent.self] else {
            return
        }
        
        
        let characterWorldSpaceTransform = originEntity.convert(transform: anchor.transform, to:browserModel.characterLeftHandAnchor)
        
        particleComponent.mainEmitter.attractionCenter.x =  characterWorldSpaceTransform.translation.x - (browserModel.characterLeftHandAnchor?.transform.translation.x ?? 0)
        particleComponent.mainEmitter.attractionCenter.y = (browserModel.characterLeftHandAnchor?.transform.translation.y ?? 0) - characterOffset.y
        particleComponent.mainEmitter.attractionCenter.z = characterWorldSpaceTransform.translation.z - (browserModel.characterLeftHandAnchor?.transform.translation.z ?? 0)
        
        browserModel.characterLeftHandAnchor?.components[ParticleEmitterComponent.self] = particleComponent
        
        browserModel.characterRightHandAnchor?.transform.translation = rightHandLocation.transform.translation
        browserModel.characterRightHandAnchor?.transform.rotation = browserModel.characterAnchor.transform.rotation
        guard var particleComponent = browserModel.characterRightHandAnchor?.components[ParticleEmitterComponent.self] else {
            return
        }
        
        
        let rightCharacterWorldSpaceTransform = originEntity.convert(transform: anchor.transform, to:browserModel.characterRightHandAnchor)
        
        particleComponent.mainEmitter.attractionCenter.x =  rightCharacterWorldSpaceTransform.translation.x - (browserModel.characterRightHandAnchor?.transform.translation.x ?? 0)
        particleComponent.mainEmitter.attractionCenter.y = (browserModel.characterRightHandAnchor?.transform.translation.y ?? 0) - characterOffset.y
        particleComponent.mainEmitter.attractionCenter.z = rightCharacterWorldSpaceTransform.translation.z - (browserModel.characterRightHandAnchor?.transform.translation.z ?? 0)
        
        browserModel.characterRightHandAnchor?.components[ParticleEmitterComponent.self] = particleComponent
        
        //                        print("Right world space translation : \(deviceWorldSpaceTransform)")
        //                        print("Right hand attraction: \(particleComponent.mainEmitter.attractionCenter)")
        
        browserModel.characterRightHandAnchor?.components[ParticleEmitterComponent.self] = particleComponent
    }
}


#Preview {
    let model = NearbyServiceBrowserModel()
    return ImmersiveView(browserModel: model, playerModel: PlayerModel(), selectedFit: .constant(.GageDarkFit))
        .previewLayout(.sizeThatFits)
}

