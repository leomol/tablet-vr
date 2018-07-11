/**
 * @file Grating.cs
 * @author Leonardo Molina (leonardomt@gmail.com)
 * @date 2016-12-01
 * @version 0.1.180711
 *
 * @brief Create a grating texture on an object with the settings provided.
 */

using UnityEngine;
using UnityEngine.UI;
using System.Collections;
using System;
using System.Threading;

public class Grating : MonoBehaviour {
	public int NCycles = 20;
	public float PixelsPerCycle = 20f;
	public float Rotation = 45f;
	public float PhaseOffset = 0f;
	public float AspectRatio = 1;
	
	Texture2D texture;
	Renderer targetRenderer;
		
	void Awake() {
		targetRenderer = GetComponent<Renderer>();
		SetCycles(NCycles, PixelsPerCycle, Rotation, PhaseOffset, AspectRatio);
	}
	
	/**
	 * @brief Replace object's texture for a custom grating.
	 * param[in] nCycles number of cycles.
	 * param[in] pixelsPerCycle numbers of pixels per cycle.
	 * param[in] rotation rotation of the grating.
	 * param[in] phaseOffset where in the cycle phase to start.
	 * param[in] aspectRatio proportion of nRows to nCols in the texture.
	 */
	void SetCycles(int nCycles, float pixelsPerCycle, float rotation, float phaseOffset, float aspectRatio) {
		int mi = Mathf.RoundToInt(nCycles * pixelsPerCycle * aspectRatio);
		int mj = (int) (nCycles * pixelsPerCycle);
		int limit = mj;
		
		float cost = 1f;
		float sint = 1f;
		int ni = 1;
		int nj = 1;
		int nr = Mathf.RoundToInt(pixelsPerCycle);
		if (IsHorizontal(rotation)) {
			cost = 0f;
			ni = Mathf.RoundToInt(pixelsPerCycle);
			mj = 1;
		} else if (IsVertical(rotation)) {
			sint = 0f;
			nj = Mathf.RoundToInt(pixelsPerCycle);
			mi = 1;
		} else {
			cost = Mathf.Cos(rotation);
			sint = Mathf.Sin(rotation);
			ni = Math.Abs(Mathf.RoundToInt(pixelsPerCycle / sint));
			nj = Math.Abs(Mathf.RoundToInt(pixelsPerCycle / cost));
			// Smallest from maximum size allowed, tile size, texture size.
			ni = (int) Mathf.Min(ni, mi, limit);
			nj = (int) Mathf.Min(nj, mj, limit);
			nr = nj;
		}
		
		float freq = nr / pixelsPerCycle;
		int ti = Math.Max(ni - 1, 1);
		int tj = Math.Max(nj - 1, 1);
		
		// Compute proportion for a given orientation.
		float[] x = new float[nj];
		float[] y = new float[ni];
		for (int j = 0; j < nj; j++) {
			float v = (j - 1f)/(nr - 1f) - 0.5f;
			x[j] = v * cost;
		}
		for (int i = 0; i < ni; i++) {
			float v = (i - 1f)/(nr - 1f) - 0.5f;
			y[i] = v * sint;
		}
		
		Color[] cols = new Color[ti*tj];
		// Otherwise stick to horizontal or vertical grids.
		for (int i = 0; i < ti; i++) {
			for (int j = 0; j < tj; j++) {
				// Convert to radians and scale by frequency.
				float v = Mathf.Sin((x[j] + y[i]) * freq * 2f * Mathf.PI + phaseOffset);
				// Make 2D sinewave.
				cols[j * ti + i].r = v;
				cols[j * ti + i].g = v;
				cols[j * ti + i].b = v;
			}
		}
		
		if (texture != null)
			Destroy(texture);
		texture = new Texture2D(ti, tj, TextureFormat.RGB24, false);
		// SetPixels is faster than SetPixel.
		texture.SetPixels(cols);
		//texture.Compress(false);
		targetRenderer.material.mainTexture = texture;
		targetRenderer.material.mainTextureScale = new Vector2(mi / (float) ni, mj / (float) nj);
		texture.Apply(false);
		
	}
	
	static bool IsHorizontal(float Rotation) {
		return Mathf.Abs(Mathf.Cos(Rotation)) < 1e-5f;
	}
	
	static bool IsVertical(float Rotation) {
		return Mathf.Abs(Mathf.Sin(Rotation)) < 1e-5f;
	}
}
