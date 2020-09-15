import Foundation
import UIKit
import SceneKit
import ARKit
import WebRTC


class TestViewController: UIViewController {
    
    // A node used for fixing the face at a point in space. The faceNode added as a child node
    lazy var dropNode: SCNNode? = {
        let dropNode = SCNNode()
        guard let camera = sceneView.pointOfView else { return nil }
        camera.addChildNode(dropNode)
        dropNode.position.z = -0.4
        // dropNode.position.y = 0.032
        dropNode.rotation = SCNVector4(0, 1, 0, Float.pi)
        return dropNode
    }()
    
    // The node that has the face that will be animated as its geomtry
    lazy var faceNode: SCNNode? = {
        guard let faceScene = SCNScene(named: "art.scnassets/Head.scn") else { return nil }
        let faceNode = faceScene.rootNode
        dropNode?.addChildNode(faceNode)
        return faceNode
    }()
    
    
    // The childNode of the faceNode corresponding to the left eye
    lazy var leftEyeNode: SCNNode? = {
        return faceNode?.childNode(withName: "leftEye", recursively: true)
    }()
    
    // The childNode of the faceNode corresponding to the right eye
    lazy var rightEyeNode: SCNNode? = {
        return faceNode?.childNode(withName: "rightEye", recursively: true)
    }()
    
    // Records if the face has been fixed at a point in space or not
    var facePlaced: Bool = false
    
    // The AR scene view and background on which user instructions are written
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var instructionsView: UIView!
    
    // Double tap to switch between the modes of the face being (i) fixed at a point in space and (ii) being fixed right in front of the camera
    @IBAction func fixInSpace(_ sender: Any) {
        toggleFixedInSpace()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        instructionsView.layer.cornerRadius = 20
        instructionsView.clipsToBounds = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration. Using ARWorldTrackingConfiguration means we can capture face data with the front facing(selfie) cam while also showing the video captured by the back facing camera
        let configuration = ARWorldTrackingConfiguration()
        if #available(iOS 13.0, *) {
            configuration.userFaceTrackingEnabled = true
        } else {
            // Fallback on earlier versions
        }
        
        configuration.isLightEstimationEnabled = true
        
        // Run the view's session
        sceneView.session.run(configuration)
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    func toggleFixedInSpace() {
        guard let dropNode = dropNode else { return }
        if facePlaced { // If the face has been fixed at a point in space then the following code fixes it in front of the camera instead
            guard let camera = sceneView.pointOfView else { return }
            
            // Remove the drop node from being a child node of the root. Add it as a child node of the camera node
            dropNode.removeFromParentNode()
            camera.addChildNode(dropNode)
            
            // Reset the drop node's position and orientation. Then rotate it so the face is looking at the camera and move the node so the face is  0.4 meters away from the camera
            dropNode.transform = SCNMatrix4Identity
            dropNode.rotation = SCNVector4(0, 1, 0, Float.pi)
            dropNode.position.z = -0.4
            
            // The face has no longer been placed at a fixed point in space
            facePlaced = false
        } else { // If the face has been fixed in front of the camera then the following code fixes it at its current poisition in space
            // Remember the drop node's current position. Remove it as a child node from the camera node and add it as a child node to the root node of the scene
            let currentPosition = dropNode.worldPosition
            dropNode.removeFromParentNode()
            sceneView.scene.rootNode.addChildNode(dropNode)
            
            // Give the drop node the current position of the face and orient it so that it is upright (the root node always is oriented so the y vector is pointing directly upwards  away from the earth)
            dropNode.worldPosition = currentPosition
            dropNode.orientation = sceneView.scene.rootNode.orientation
            
            // The face has been placed at a fixed point in space
            facePlaced = true
        }
    }
}

// ***************************************************************************************************************************************************************************//
//                                                                           AR Scene View Delegate                                                                           //
//*************************************************************************************************************************************************************************** //

extension TestViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor, let camera = sceneView.pointOfView else { return }
        // Blendshapes are the 52 coefficients used to animate a face
        let blendShapes = faceAnchor.blendShapes
        
        // Get the transforms (orientation, position and scale) of the face and eyes from the user
        let rootNode = sceneView.scene.rootNode
        let faceTransform = SCNMatrix4(faceAnchor.transform)
        let leftEyeTransform = SCNMatrix4(faceAnchor.leftEyeTransform)
        let rightEyeTransform = SCNMatrix4(faceAnchor.rightEyeTransform)
        
        // Convert the face transform from world space to camera space
        let faceTransformRelativeToCamera = rootNode.convertTransform(faceTransform, to: camera)
        
        // Get the quaternionic representation of the rotation for the following transform matrices
        let faceOrientation = faceTransformRelativeToCamera.getOrientationQuaternion()
        let leftEyeOrientation = leftEyeTransform.getOrientationQuaternion()
        let rightEyeOrientation = rightEyeTransform.getOrientationQuaternion()
        
        // Give the nodes of the face geoemtry to be animated the appropriate orientations (so the face and eyes move and face in directions corresponding to how the user moves their face and eyes)
        faceNode?.orientation = faceOrientation
        leftEyeNode?.orientation = leftEyeOrientation
        rightEyeNode?.orientation = rightEyeOrientation
        
        // The following mirrors the face for cosmetic reasons
        guard let orientation = faceNode?.simdOrientation else { return }
        faceNode?.simdOrientation = simd_quaternion(orientation.angle, simd_float3(orientation.axis.x, -orientation.axis.y, -orientation.axis.z))
        
        // The morpher applies the blend shape coefficients to the face geometry to animate in with the facial expressions of the user
        let morpher = faceNode?.childNodes.first?.morpher
        
        for (key, value) in blendShapes {
            morpher?.setWeight(CGFloat(truncating: value), forTargetNamed: key.rawValue)
        }
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
}


// ***************************************************************************************************************************************************************************//
//                                                                           AR Session Delegate                                                                              //
//*************************************************************************************************************************************************************************** //


extension TestViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // This block of code makes the face geometry always look (roughly) in the direction of the user when the face goemetry has been fixed at a point in space
        if facePlaced {
            guard let camera = sceneView.pointOfView else { return }
            dropNode?.orientation = sceneView.scene.rootNode.orientation
            dropNode?.look(at: camera.position)
        }
    }
}
