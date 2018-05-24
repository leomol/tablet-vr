v0.1.0

# Tablet VR
Controller for virtual reality tasks for execution of arbitrary experimental paradigms. The virtual environments (aka scenes) are displayed in a number of monitor tablets around the field of view of the subject.

![alt text](http://www.interphaser.com/images/content/smoothwalk-hardware-setup-labeled.png "Tablet based VR")

## Getting Started
Here's a short video showing how to run an example, assuming you fullfill the prerequisites:
[Getting started]

## Prerequisites
* MATLAB.
* If using scenes provided
	* [TabletVR.exe][TabletVR.exe]
* Otherwise, if compiling new scenes
	* [Unity 3D][Unity 3D]
	* [Android Studio][Android Studio]
	* [Java SDK][Java SDK]
* Port UDP 32000 enabled in the firewall/network for MATLAB, Unity, and any future compilations.

Code was last built and tested with
* MATLAB R2018a
* Unity 2018.a.0f2
* Java JDK1.8.0_172
* Android Studio 3.1.2
	* Android SDK Platform 27 revision 3
	* Android SDK Build-Tools 28-rc2 version 28.0.0 rc2
* PC
	* OS: Windows 10
	* CPU: Intel i7-6700HQ
	* RAM: 16 GB
	* Graphics: GEFORCE GTX 960M
	* SSD: Samsung SM951
* Tablets
	* OS: Android 5.0
	* SoC: Qualcomm Snapdragon 410 APQ8016

## Installation
* Install MATLAB
	* Download library from repository and place the MATLAB folder under Documents folder.
	* Create/modify Documents/MATLAB/startup.m and put `addpath('Tools');`

* If creating new scenes
	* Install Java SDK.
Add <java-installation-path>/bin to the System Enviroment Variables.
	* Install Android Studio.
	* Install Unity, adding support for Android.
	* Open Unity and create a new project.
	* Import the [Unity package][Unity package] or add the <>source code for Unity.
* Otherwise
	* Run [TabletVR.exe][TabletVR.exe] in your PC.
	* Run [TabletVR.apk][TabletVR.apk] in each tablet.

* If using an Arduino in your treadmill
	* Run [upload-firmware.vbs][upload-firmware.vbs] and follow instructions.
	
## Testing scenes in Unity
* Add scenes to build settings.
* Open Main scene and hit play.

## Deployment
* Add scenes to build settings.
* Open Main scene.
* Build for Android.
* Run [TabletVR.apk][TabletVR.apk] in each tablet.
	
## Usage examples
* Run [TabletVR.exe][TabletVR.exe] or run the Main scene in Unity.
* Open MATLAB.
* Run the examples below.
* After each example, type `delete(obj);` to release resources.

### Example 1
```matlab
	obj = CircularMaze();
	obj.start();
```

### Example 2
```matlab
	obj = LinearMaze();
	obj.start();
	obj.speed = 15;
	pause(3);
	obj.speed = 1;
```

### Example 3
```matlab
	sender = UDPSender(32000);
	sender.send('scene,Classroom;enable,Menu,0;', '127.0.0.1');
	for i = 1:10
		Tools.tone(1250, 0.5);
		sender.send('enable,Blank,1;', '127.0.0.1');
		pause(0.25);
		
		sender.send(sprintf('rotation,Main Camera,0,%.2f,0;', 360 * rand), '127.0.0.1');
		
		Tools.tone(2250, 0.5);
		sender.send('enable,Blank,0;', '127.0.0.1');
		pause(1);
	end
```

## API Reference
In MATLAB type help followed by the name of any Class (files copied to Documents/MATLAB). Most class list methods and properties with links to expand the description. For example, `help LinearMaze`.

## Version History
0.2
* TreadmillMaze.m moved to LinearMaze.m
* Tracker/GUI.m moved to Tracker.m
* Arguments to LinearMaze.m and CircleMaze.m are passed as key-value pairs, e.g., `CircleMaze('com', 'COM4', 'monitors', {'127.0.0.1', 0, '192.168.1.100', 90})`
0.1
Initial Release: Library and example code

## License
© 2018 [Leonardo Molina][Leonardo Molina]

This project is licensed under the [GNU GPLv3 License][LICENSE.md].

[Java SDK]: http://www.oracle.com/technetwork/java/javase/downloads/index.html
[Unity 3D]: https://unity3d.com/unity
[Android Studio]: https://developer.android.com/studio

[Getting started]: https://drive.google.com/open?id=1PznYQcsR23NS4EQ-l4tKz5mKU-1TjS-7
[Leonardo Molina]: https://github.com/leomol

[LICENSE.md]: LICENSE.md
[Unity package]: bin/TabletVR.unitypackage
[TabletVR.exe]: bin/TabletVR.exe
[TabletVR.apk]: bin/TabletVR.apk
[upload-firmware.vbs]: bin/upload-firmware.vbs
