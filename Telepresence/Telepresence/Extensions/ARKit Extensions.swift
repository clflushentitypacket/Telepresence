import ARKit

typealias Blendshapes = [ARFaceAnchor.BlendShapeLocation: NSNumber]

typealias CGBlendshapes = [ARFaceAnchor.BlendShapeLocation: CGFloat]

struct Constants {
    // An array of blend shape locations, ordered alphabetically
    static let blendShapeLocations: [ARFaceAnchor.BlendShapeLocation] = [.browDownLeft, .browDownRight, .browInnerUp, .browOuterUpLeft, .browOuterUpRight, .cheekPuff, .cheekSquintLeft, .cheekSquintRight, .eyeBlinkLeft, .eyeBlinkRight, .eyeLookDownLeft, .eyeLookDownRight, .eyeLookInLeft, .eyeLookInRight, .eyeLookOutLeft, .eyeLookOutRight, .eyeLookUpLeft, .eyeLookUpRight, .eyeSquintLeft, .eyeSquintRight, .eyeWideLeft, .eyeWideRight, .jawForward, .jawLeft, .jawOpen, .jawRight, .mouthClose, .mouthDimpleLeft, .mouthDimpleRight, .mouthFrownLeft, .mouthFrownRight, .mouthFunnel, .mouthLeft, .mouthLowerDownLeft, .mouthLowerDownRight, .mouthPressLeft, .mouthPressRight, .mouthPucker, .mouthRight, .mouthRollLower, .mouthRollUpper, .mouthShrugLower, .mouthShrugUpper, .mouthSmileLeft, .mouthSmileRight, .mouthStretchLeft, .mouthStretchRight, .mouthUpperUpLeft, .noseSneerLeft, .noseSneerRight, .tongueOut]
}


extension Blendshapes {
    func convertToArray() -> [Float] {
        var result: [Float] = []
        for blendShapeLocation in Constants.blendShapeLocations {
            result.append(self[blendShapeLocation]!.floatValue)
        }
        return result
    }
}


extension Array where Element == Float {
    func convertToCGBlendshapes() -> CGBlendshapes {
        var result: CGBlendshapes = [:]
        for (index, blendShapeLocation) in Constants.blendShapeLocations.enumerated() {
            result[blendShapeLocation] = CGFloat(self[index])
        }
        return result
    }
}


extension Array where Element == Float {
    func convertToSCNQuaternion() -> SCNQuaternion {
        return SCNQuaternion(self[0], self[1], self[2], self[3])
    }
}


extension SCNQuaternion {
    func convertToArray() -> [Float] {
        return [self.x, self.y, self.z, self.w]
    }
}


extension SCNMatrix4 {
    // The use if the tempNode in the following code is possibly inefficient.
    func getOrientationQuaternion() -> SCNQuaternion {
        let tempNode: SCNNode = SCNNode()
        
        tempNode.transform = self
        return tempNode.orientation
    }
}
