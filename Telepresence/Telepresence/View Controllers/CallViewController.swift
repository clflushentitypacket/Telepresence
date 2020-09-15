import UIKit
import SceneKit
import ARKit
import WebRTC

class CallViewController: UIViewController {
    // A node used for fixing the face at a point in space. The faceNode is added as a child node
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
    
    //The manager for data being sent and received by the device via WebRTC.
    var networkManager: NetworkManager!
    var user: User!
    
    // Records if the face has been fixed at a point in space or not
    var facePlaced: Bool = false
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var statusView: UIView!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var statusLabel: UILabel!
    
    @IBAction func fixInSpace(_ sender: Any) {
        toggleFixedInSpace()
    }
    
    @IBAction func callButton(_ sender: Any) {
        networkManager.connect()
        connectButton.isHidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        networkManager = NetworkManager(user)
        networkManager.peerConnection?.delegate = self
        networkManager.dataChannel?.delegate = self
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        
        statusView.layer.cornerRadius = 5
        statusView.clipsToBounds = true
        
        if user == .caller {
            connectButton.layer.cornerRadius = 5
            connectButton.clipsToBounds = true
        } else {
            connectButton.isHidden = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration. Using ARWorldTrackingConfiguration means we can capture face data with the front facing (selfie) cam while also showing the video captured by the back facing camera
        let configuration = ARWorldTrackingConfiguration()
        if #available(iOS 13.0, *) {
            configuration.userFaceTrackingEnabled = true
        } else {
            print("Please update to iOS 13 or higher")
        }
        
        configuration.isLightEstimationEnabled = true
        // Set the quality of the video feed to be lowest to improve performance
        let lowestQualityVideoFormat = ARWorldTrackingConfiguration.supportedVideoFormats.last
        configuration.videoFormat = lowestQualityVideoFormat!
        // Run the view's session
        sceneView.session.run(configuration)
        sceneView.autoenablesDefaultLighting = true
        // The following line can be uncommented to improve performance (but decrease the quality of the facial expression data captured
        // sceneView.preferredFramesPerSecond = 30
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        if self.isMovingFromParent {
            networkManager.closeConnection()
        }
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

extension CallViewController: ARSCNViewDelegate {
    
    // Capture and transmit the facial expression data and the orientation of the face and eyes
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor, let camera = sceneView.pointOfView else { return }
        let generatedBlendShapes = faceAnchor.blendShapes
        
        let rootNode = sceneView.scene.rootNode
        let faceTransform = SCNMatrix4(faceAnchor.transform)
        let leftEyeTransform = SCNMatrix4(faceAnchor.leftEyeTransform)
        let rightEyeTransform = SCNMatrix4(faceAnchor.rightEyeTransform)
        
        let faceTransformRelativeToCamera = rootNode.convertTransform(faceTransform, to: camera)
        
        let faceOrientation = faceTransformRelativeToCamera.getOrientationQuaternion()
        let leftEyeOrientation = leftEyeTransform.getOrientationQuaternion()
        let rightEyeOrientation = rightEyeTransform.getOrientationQuaternion()
        
        networkManager.send(generatedBlendShapes, faceOrientation, leftEyeOrientation, rightEyeOrientation)
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


extension CallViewController: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // This block of code makes the face geometry always look (roughly) in the direction of the user when the face goemetry has been fixed at a point in space
        if facePlaced {
            guard let camera = sceneView.pointOfView else { return }
            dropNode?.orientation = sceneView.scene.rootNode.orientation
            dropNode?.look(at: camera.position)
        }
    }
}


// ***************************************************************************************************************************************************************************//
//                                                                        Network manager Delegates                                                                           //
//*************************************************************************************************************************************************************************** //


// MARK:- The (Web)RTC Data Channel Delegate

extension CallViewController: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        if let state = self.networkManager.dataChannel?.readyState.description {
            print("Data channel changed state to: \(state)")
        }
    }
    
    // Decode the facial expression, face and eye orientation data received from the other device and then update the 3d model with it
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        // The following JSON decoding code might not be the optimal thing to do
        let decoder = JSONDecoder()
        let data = buffer.data
        
        guard let decodedData = try? decoder.decode([[Float]].self, from: data) else { return }
        
        let blendShapes = decodedData[0].convertToCGBlendshapes()
        let faceOrientation = decodedData[1].convertToSCNQuaternion()
        let leftEyeOrientation = decodedData[2].convertToSCNQuaternion()
        let rightEyeOrientation = decodedData[3].convertToSCNQuaternion()
        
        faceNode?.orientation = faceOrientation
        leftEyeNode?.orientation = leftEyeOrientation
        rightEyeNode?.orientation = rightEyeOrientation
        
        leftEyeNode?.eulerAngles.x += 0.2
        rightEyeNode?.eulerAngles.x += 0.2
        
        let morpher = faceNode?.childNodes.first?.morpher
        
        for (key, value) in blendShapes {
            morpher?.setWeight(value, forTargetNamed: key.rawValue)
        }
        
    }
}


// MARK: - The (Web)RTC Peer Connection Delegate

extension CallViewController: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        print("RTCPeerConnection did change its RTCSignalingState to: \(stateChanged.description)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        print("RTCPeerConnection did add an RTCMediaStream")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
        print("RTCPeerConnection did remove an RTCMediaStream")
        
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        print("RTCPeerConnection should negotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        print("RTCPeerConnection did change its RTCIceConnectionState to: \(newState.description)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCPeerConnectionState) {
        DispatchQueue.main.async {
            self.statusLabel.text = "Status: \(newState.description)"
        }
        if newState == .connected  {
            networkManager.initializeAudio()
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        print("RTCPeerConnection did change its RTCIceGatheringState to: \(newState.description)")
        
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        print("RTCPeerConnection did generate an RTCIceCandidate")
        self.networkManager.updateCandidate(with: candidate)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
        print("RTCPeerConnection did remove an RTCIceCandidate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("RTCPeerConnection did open an RTCDataChannel")
        dataChannel.delegate = self
        networkManager.dataChannel = dataChannel
    }
}
