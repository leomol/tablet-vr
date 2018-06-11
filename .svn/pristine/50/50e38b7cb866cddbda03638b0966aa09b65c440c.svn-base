/*
	2017-06-05. Leonardo Molina.
	2018-03-28. Last modification.
 */

using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
#if UNITY_EDITOR
using UnityEditor;
#endif
using Random = System.Random;

namespace TabletVR {
	public class Starry : MonoBehaviour {
		public int tileNi = 6; 			// Tile size
		public int tileNj = 6;			
		public int dotNi = 2;			// Dot size.
		public int dotNj = 2;			
		public int marginNi = 1;		// Tile inner margin.
		public int marginNj = 1;		
		public int ni = 3; 				// Number of tiles.
		public int nj = 3;				
		public float repeatKi = 1f; 	// Repetitions.
		public float repeatKj = 1f;	
		public float ratio = 0.75f; 	// Probability on.
		public float interval = 0.5f; 	// Blinkin frequency.
		
		static Random random = new Random(0);
		static Random randomBlink = new Random(1);
		Material material;
		Texture2D texture;
		static bool once = true;
		
		void Awake() {
			material = new Material(Shader.Find("Unlit/Texture"));
			#if UNITY_EDITOR
			if (once) {
				once = false;
				// Create an asset once so that the shader is included during compilation.
				string target = "Assets/Resources/UnlitMaterial";
				string materialTarget = string.Format("{0}.mat", target);
				// Save texture and material, otherwise prefabs build from these won't load these components.
				AssetDatabase.CreateAsset(material, materialTarget);
			}
			#endif
			gameObject.GetComponent<Renderer>().material = material;
		}
		
		IEnumerator Start() {
			if (ratio == 1f || ratio == 0f || interval == 0f) {
				NewTexture();
				yield return null;
			} else {
				while (true) {
					NewTexture();
					yield return new WaitForSeconds(interval);
				}
			}
		}
		
		void NewTexture() {
			int canvasNi = ni * tileNi;
			int canvasNj = nj * tileNj;
			
			Color[] canvas = new Color[canvasNi * canvasNj];
			int di = tileNi - 2 * marginNi - dotNi;
			int dj = tileNj - 2 * marginNj - dotNj;
			for (int i = 0; i < canvasNi; i += tileNi) {
				for (int j = 0; j < canvasNj; j += tileNj) {
					int ri = random.Next(di + 1) + marginNi;
					int rj = random.Next(dj + 1) + marginNj;
					if (randomBlink.NextDouble() >= (1f - ratio)) {
						for (int ii = ri; ii < ri + dotNi; ii++) {
							for (int jj = rj; jj < rj + dotNj; jj++) {
								// int kk = (j + jj) + (i + ii) * canvasNj;
								int kk = (i + ii) + (j + jj) * canvasNi;
								canvas[kk] = Color.white;
							}
						}
					}
				}
			}
			
			Destroy(texture);
			texture = new Texture2D(canvasNi, canvasNj, TextureFormat.RGBA32, false);
			texture.SetPixels(canvas);
			texture.Apply();
			texture.filterMode = FilterMode.Point;
			texture.wrapMode = TextureWrapMode.Repeat;
			material.mainTexture = texture;
			material.mainTextureScale = new Vector2(repeatKi, repeatKj);
		}
		
		void OnDestroy() {
			Destroy(texture);
		}
	}
}