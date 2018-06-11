/*
	Tablet VR - Main class defining GUIs and behavior.
	Network data is deserialize to control the visibility, position, rotation and dimensions of objects in the mainScene.
	
	leonardomt@gmail.com
	Last edit: 2018-04-16.
*/

using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

namespace TabletVR {
	using TabletVR.Network;
	public class Main : MonoBehaviour {
		// Look-up table for existing game-objects.
		Dictionary<string, GameObject> objects = new Dictionary<string, GameObject>();
		
		// UI components.
		GameObject menuObject;
		Text logText;
		Coroutine loadScene;
		string sceneName = "";
		Scene mainScene;
		static GameObject mainObject;
		Camera mainCamera;
		
		// Default settings.
		const string version = "20180416";
		const int port = 32000;
		
		void Awake() {
			// Run when not in focus.
			Application.runInBackground = true;
			// Don't let the screen go to sleep.
			Screen.sleepTimeout = SleepTimeout.NeverSleep;
			
			// Get a reference of main objects.
			foreach (Transform child in transform)
				objects[child.name] = child.gameObject;
			
			// Keep this object across scenes.
			mainObject = gameObject;
			DontDestroyOnLoad(mainObject);
			mainScene = SceneManager.GetActiveScene();
			
			// Setup UI components.
			menuObject = GameObjectByName("Menu");
			logText = GameObjectByName("Menu").GetComponentInChildren<Text>();
			menuObject.SetActive(true);
			
			// Print program information on the screen.
			Log("Version: " + version);
			Log("About: leonardomt@gmail.com");
			
			// Attach and setup up communication component.
			Receiver receiver = gameObject.AddComponent<Receiver>();
			receiver.DataReceived += (source, data) => OnDataReceived(data);
			if (!receiver.Setup(port))
				Log("Port {0} is unavailable in this device and remote data won't reach this device.", port);
		}
		
		void Update() {
			// Toggle GUI menuObject.
			if (Input.GetKeyDown(KeyCode.Escape))
				menuObject.SetActive(!menuObject.activeSelf);
		}
		
		/*
			Log(message, formatArgument1, formatArgument2, ...)
			Print a timestamped "MSDN Composite Formatted" message on the screen.
			For example:
				Log("Hello {0}", "Leo");
			would print
				[0.0020] Hello Leo.
		*/
		void Log(string message, params object[] parameters) {
			message = string.Format(message, parameters);
			string text = string.Format("[{0:0000.00}] {1}\n{2}", Time.realtimeSinceStartup, message, logText.text);
			logText.text = text.Substring(0, Math.Min(2048, text.Length));
		}
		
		/*
			OnDataReceived(data)
			Deserialize data received from the network.
			Data consists on statements which are separated by semicolons. For example:
				data: statement1;
				data: statement1;statement2;...
		*/
		void OnDataReceived(string data) {
			int max = 5;
			if (data.Length > 1) {
				int statementBegin = 0;
				while (max-- > 0) {
					int statementLength = data.Substring(statementBegin).IndexOf(';');
					if (statementLength == -1) {
						break;
					} else {
						string statement = data.Substring(statementBegin, statementLength);
						ParseStatement(statement);
						statementBegin += statementLength + 1;
					}
				}
			}
		}
		
		/*
			ParseStatement(statement)
			Deserialize a statement, which consists of a function name or
			function name, a comma, and an argument (which may or may not consist of further CSV):
				statement: function-name
				statement: function-name,argument
		*/
		void ParseStatement(string statement) {
			string functionName = null;
			string functionArgument = null;
			int nameEnd = statement.IndexOf(',');
			bool success = true;
			if (nameEnd == -1) {
				functionName = statement;
			} else if (nameEnd > 0){
				functionName = statement.Substring(0, nameEnd);
				functionArgument = statement.Substring(nameEnd + 1);
			} else {
				success = false;
			}
			if (success) {
				functionName = functionName.Trim();
				switch (functionName) {
					case "position":
						ParsePosition(functionArgument);
						break;
					case "rotation":
						ParseRotation(functionArgument);
						break;
					case "scale":
						ParseScale(functionArgument);
						break;
					case "scene":
						ParseScene(functionArgument);
						break;
					case "enable":
						ParseEnable(functionArgument);
						break;
					case "":
						break;
					default:
						Log("'{0}' is not a recognized function name.", functionName);
						break;
				}
			}
		}
		
		/*
			ParseEnable(data)
			Deserialize an enable operation on a game object.
			Data consists of the name of the target object followed by
			0 or 1, separated by a comma:
				px,py,pz,rx,ry,rz,sx,sy,sz
		*/
		void ParseEnable(string data) {
			bool success;
			string[] parts;
			try {
				parts = data.Split(',');
				success = parts.Length == 2;
			} catch {
				parts = null;
				success = false;
			}
			
			if (success) {
				string objectName = parts[0].Trim();
				GameObject gameObject = GameObjectByName(objectName);
				if (gameObject == null) {
					Log("'{0}' has not been loaded in the scene.", objectName);
				} else {
					int enable;
					if (int.TryParse(parts[1], out enable) && (enable == 1 || enable == 0)) {
						gameObject.SetActive(enable == 1);
					} else {
						Log("'{0}' is not a valid value for 'enable'.", objectName);
					}
				}
			}
		}
		
		/*
			ParsePosition(data)
			Deserialize a position operation on a game object.
			Data consists of the name of the target object followed by
			a position vector: name,px,py,pz
		*/
		void ParsePosition(string data) {
			bool success;
			string[] parts;
			const int nNumbers = 3;
			try {
				parts = data.Split(',');
				success = parts.Length == nNumbers + 1;
			} catch {
				parts = null;
				success = false;
			}
			string objectName = success ? parts[0].Trim() : null;
			
			if (success) {
				Transform transform = TransformByName(objectName);
				if (transform == null) {
					Log("'{0}' has not been loaded in the scene.", objectName);
					success = false;
				} else {
					float[] numbers = new float[nNumbers];
					for (int p = 0; p < nNumbers; p++) {
						float number;
						if (float.TryParse(parts[p + 1], out number)) {
							numbers[p] = number;
						} else {
							success = false;
							break;
						}
					}
					if (success) {
						transform.localPosition = new Vector3(numbers[0], numbers[1], numbers[2]);
					} else {
						Log("'{0}' are not valid parameters for 'position'.", data);						
					}
				}
			} else {
				Log("'{0}' are not valid parameters for 'position'.", data);
			}
		}
		
		/*
			ParseRotation(data)
			Deserialize a rotation operation on a game object.
			Data consists of the name of the target object followed by
			a rotation vector: name,rx,ry,rz
		*/
		void ParseRotation(string data) {
			bool success;
			string[] parts;
			const int nNumbers = 3;
			try {
				parts = data.Split(',');
				success = parts.Length == nNumbers + 1;
			} catch {
				parts = null;
				success = false;
			}
			string objectName = success ? parts[0].Trim() : null;
			
			if (success) {
				Transform transform = TransformByName(objectName);
				if (transform == null) {
					Log("'{0}' has not been loaded in the scene.", objectName);
					success = false;
				} else {
					float[] numbers = new float[nNumbers];
					for (int p = 0; p < nNumbers; p++) {
						float number;
						if (float.TryParse(parts[p + 1], out number)) {
							numbers[p] = number;
						} else {
							success = false;
							break;
						}
					}
					if (success) {
						transform.localEulerAngles = new Vector3(numbers[0], numbers[1], numbers[2]);
					} else {
						Log("'{0}' are not valid parameters for 'rotation'.", data);						
					}
				}
			} else {
				Log("'{0}' are not valid parameters for 'rotation'.", data);
			}
		}
		
		/*
			ParseScale(data)
			Deserialize a scale operation on a game object.
			Data consists of the name of the target object followed by
			a scale vector: name,sx,sy,sz
		*/
		void ParseScale(string data) {
			bool success;
			string[] parts;
			const int nNumbers = 3;
			try {
				parts = data.Split(',');
				success = parts.Length == nNumbers + 1;
			} catch {
				parts = null;
				success = false;
			}
			string objectName = success ? parts[0].Trim() : null;
			
			if (success) {
				Transform transform = TransformByName(objectName);
				if (transform == null) {
					Log("'{0}' has not been loaded in the scene.", objectName);
					success = false;
				} else {
					float[] numbers = new float[nNumbers];
					for (int p = 0; p < nNumbers; p++) {
						float number;
						if (float.TryParse(parts[p + 1], out number)) {
							numbers[p] = number;
						} else {
							success = false;
							break;
						}
					}
					if (success)
						transform.localScale = new Vector3(numbers[0], numbers[1], numbers[2]);
					else
						Log("'{0}' are not valid parameters for 'scale'.", data);
				}
			} else {
				Log("'{0}' are not valid parameters for 'scale'.", data);
			}
		}
		
		/*
			ParseScene(data)
			Deserialize a load scene operation.
			Data consists of the name of an existing scene.
		*/
		void ParseScene(string data) {
			if (loadScene != null)
				StopCoroutine(loadScene);
			loadScene = StartCoroutine(LoadSceneAsync(data.Trim()));
		}
		
		IEnumerator LoadSceneAsync(string name) {
			if (ValidSceneName(name)) {
				if (!sceneName.Equals(name, StringComparison.InvariantCultureIgnoreCase)) {
					SceneManager.MoveGameObjectToScene(Main.mainObject, mainScene);
					SceneManager.SetActiveScene(mainScene);
					
					AsyncOperation asyncOperation;
					
					// Unload previous scene first, then load and remember new scene name.
					if (sceneName != String.Empty) {
						asyncOperation = SceneManager.UnloadSceneAsync(sceneName); 
						yield return new WaitUntil(() => asyncOperation.isDone);
					}
					
					// Load new scene and move main objects there.
					sceneName = name;
					asyncOperation = SceneManager.LoadSceneAsync(name, LoadSceneMode.Additive);
					asyncOperation.allowSceneActivation = true;
					Log("Loading '{0}' ...", name);
					yield return new WaitUntil(() => asyncOperation.isDone);
					SceneManager.MoveGameObjectToScene(Main.mainObject, SceneManager.GetActiveScene());
					
					// Keep only the last camera.
					Camera last = mainCamera;
					foreach (Camera cam in Camera.allCameras) {
						if (cam != mainCamera) {
							cam.gameObject.SetActive(false);
							last = cam;
						}
					}
					// Keep only the main camera.
					if (last != mainCamera)
						Destroy(mainCamera);
					mainCamera = last;
					mainCamera.gameObject.SetActive(true);
					
					objects[mainCamera.name] = mainCamera.gameObject;
				} else {
					Log("'{0}' is already loaded.", name);
				}
			} else {
				Log("'{0}' is not a valid scene name.", name);
			}
		}
		
		bool ValidSceneName(string name) {
			return !name.Equals("Main", StringComparison.InvariantCultureIgnoreCase) && SceneUtility.GetBuildIndexByScenePath(name) >= 0;
		}
		
		/*
			gameObject = GameObjectByName(name)
			Return a GameObject by name. Maintain a reference for subsequent faster retrieval.
		*/
		GameObject GameObjectByName(string name) {
			GameObject gObject;
			if (objects.ContainsKey(name) && objects[name] != null) {
				gObject = objects[name];
			} else {
				gObject = GameObject.Find(name);
				objects[name] = gObject;
			}
			return gObject;
		}
		
		/*
			transform = TransformByName(name)
			Return a transform by name. Maintain a reference for subsequent faster retrieval.
		*/
		Transform TransformByName(string name) {
			GameObject gObject = GameObjectByName(name);
			return gObject == null ? null : gObject.transform;
		}
	}
}