# Telepresence
Telepresence is an open-source demo showcasing the viability of augmented reality real-time communication

# Contact

Feel free to drop me an email on flushedentitypacket@gmail.com if you have any questions whatsoever.

# Introduction

Telepresence is an open-source demo showcasing the viability of augmented reality real-time communication (and the fruit of having too much free time over lockdown). Telepresence can be run on any iPhone X devices or later.

Suppose we have two people, Tom and Jerry. Telepresence allows Tom and Jerry to communicate with each other in a similar way to video chat. The difference is that Tom will appear right in front of Jerry (and vice versa) as a Holographic avatar via Jerry's iPhone's augmented reality capabilities:

The avatar appearing in front of Jerry will have the same real-time facial expressions and speech as Tom.  Jerry will be able to chat to Tom as if he is right in front of him – and vice versa.

The avatar can be any suitably rigged 3d-model but the technology does not currently exist, however, to make it look like the user in real-time.
In time one would expect augmented reality real-time communication will become an important new category of real-time communication in its own right, perhaps even the successor to video and audio chat before it.

# Installation Instructions

Be warned: the installation will take a bit of time and there will be plenty of waiting around for various things to finish.

### Import a rigged model of a 3d head

Telepresence requires a rigged 3d-model of a face or head. See the separate section below on sourcing a rigged model for how to obtain one. The app will not work until you have sourced and imported a rigged model.

### Install the pods

Open terminal and cd into the directory with the Podfile. Install the pods by executing the command “pod install” in terminal.

### Compile and importing WebRTC framework

Data transmission in Telepresence runs over Google's WebRTC, an open-source real-time communcation framework. You will have to build WebRTC from its source code to obtain a framework which can be imported into Xcode. To build the WebRTC framework from its source code follow the instructions here: https://webrtc.googlesource.com/src/+/refs/heads/master/docs/native-code/ios/index.md. It can take some time to download the source code from Google's repositories so don't worry if terminal hangs for a long time.

Once finished, open up Telepresence.xcworkspace and copy the resulting WebRTC.framework into the (Telepresence) Frameworks folder in Xcode (not the Pods Frameworks folder). 

Click Telepresence at the top of the project navigator and in Targets Telepresence make sure that Embed & Sign is selected for WebRTC.framework in the Frameworks, Libraries, and Embedded Content section.

### Setting up Firebase signaling server

WebRTC requires what is called a signaling server to connect two devices. Telepresence uses Google's Firebase for this purpose. One can integrate Telepresence with Firebase via the following:

1. Create a Firebase account at firebase.google.com
2. Follow steps 1-3 at https://firebase.google.com/docs/ios/setup?authuser=0. The pods have already been installed
3. Creat a Cloud Firestore database by following https://firebase.google.com/docs/firestore/quickstart?authuser=0#ios. The pods have already been installed

If you are just testing Telepresence with two devices over the same WiFi network then the above is enough. If the devices are to be connected over the internet then you will need to look into setting up separate special types of servers called STUN and TURN servers.

The details of your STUN/TURN server would need to be entered into the array “rtcConfig.iceServers” in NetworkManager.swift file.  A number of public STUN/TURN server have been included in NetworkManager.swift which one can use for testing purposes. Do not assume these servers are secure or will contiune to work.

You can now compile and run Telepresence.

### Once running

Once compiled and running there are three modes. Test mode allows one to see what it would be like if you called your own device. The other two call and receive are used to connect two devices together. More detailed usage instructions can be found by tapping the question mark in the call and recieve modes.

# Sourcing a Rigged Model

Telepresence requires a rigged 3d-model of a face or head. The best quality but most expensive option is to go to some marketplace such as cgtrader, buy a model you like and then have polywink.com rig it for you. In total this should cost about $350. Personally speaking, it's totally worth it to see a high quality model speak to you in real time.

Apart from this there are a limited supply of freely available such models. One is the kite boy 3d model which can be found in Unreal Engines Face AR Sample https://docs.unrealengine.com/en-US/Platforms/AR/HandheldAR/FaceARSample/index.html. The model is of incredibly high quality but unfortunately it utilizes a more sophisticated facial rig system than implemented in Telepresence.

The other option is Polywink's sample face rig which is licensed for personal testing use under a  CC NonCommercial NonDerivatives Attribution license and can be found at https://www.polywink.com/15-facial-animation-for-iphone-x.html. This model works fine but is not textured and so will not look as realistic as it could otherwise.

The following instructions detail how to import Polywink's sample model into Telepresence (check with Polywink first to make sure you have the right to do so for private personal use):

1. Import the .fbx file into Blender
2. Delete everything except the Neutral head
3. Move the head to the center of the scene
4. Set the X,Y and Z location to all be 0 and then select object - > apply all transforms (in particular make sure that rotations are also applied)
5. Run the following script in Blender to rename the blendshapes to the form ARKit uses https://github.com/clflushentitypacket/ARKit-Shapekey-Renamer
6. Select the head and export it as a .dae file. When exporting make sure to check the boxes Selection Only, Include Children and Include Shape Keys
7. Run the following script on the exported .dae file https://github.com/JakeHoldom/ColladaMorphAdjuster. For usage of this script see the relevant section in https://medium.com/better-programming/exporting-a-3d-character-from-blender-2-8-to-xcode-and-implement-like-animoji-using-arkit-scenekit-3d223aa6a29f
8. Import the modified .dae file into xcode's art.scnassets folder
9. Use Xcode to convert the .dae file to a .scn file (via the editor menu). Rename the .scn file to Head.scn
10. Select the head model in the .scn file. In the attributes inspector of the .scn file check the unifies normals box and on opening the gear icon select optimize morphers
11. In the Node Inspector set the y and z rotation values of the head both to 180 degrees     
12. Rename the node (in the scene graph) from Neutral to Head
13. In both the files TestViewController.swift and CallViewController.swift uncomment the line “dropNode.position.y = 0.032”

### License

Telepresence is licensed under [CC BY-NC-ND](https://creativecommons.org/licenses/by-nc-nd/4.0/). For educational, personal or indie dev use the NC-ND part will almost certainly be waived - just drop me an email.

### Credits

The WebRTC part of this project includes one or two minor code snippets from https://github.com/stasel/WebRTC-iOS/blob/master/LICENSE.md
