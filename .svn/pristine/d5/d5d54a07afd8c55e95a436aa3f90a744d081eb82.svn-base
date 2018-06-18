/*
	Tablet VR - Network data package receiver.
	leonardomt@gmail.com
	Last edit: 2018-03-09.
*/

using System;
using System.Collections;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using UnityEngine;
using UnityEngine.Networking;

namespace TabletVR.Network {
	class Receiver : MonoBehaviour {
		public delegate void DataReceivedHandler(Receiver receiver, string data);
		public event DataReceivedHandler DataReceived;
		
		Queue<string> inputs = new Queue<string>();
		readonly object inputsLock = new object();
		readonly object socketLock = new object();
		UdpClient socket;
		bool running = false;
		bool run = true;
		
		void Awake() {
			Thread thread = new Thread(new ThreadStart(ReceiveLoop));
			thread.IsBackground = true;
			thread.Start();
		}
		
		IEnumerator Start() {
			// Keep network from sleeping.
			while (true) {
				UnityWebRequest request = UnityWebRequest.Head("http://www.example.com");
				yield return request.SendWebRequest();
				yield return new WaitForSeconds(1f);
			}
		}
		
		
		void Update() {
			// Invoke callbacks in the main thread. Use a copy to unlock thread asap.
			if (DataReceived != null) {
				Queue<string> inputsCopy;
				lock (inputsLock) {
					inputsCopy = inputs;
					inputs = new Queue<string>();
				}
				while (inputsCopy.Count > 0)
					DataReceived(this, inputsCopy.Dequeue());
			}
		}
		
		void OnDestroy() {
			run = false;
		}
		
		public void Stop() {
			lock (socketLock) {
				if (running) {
					socket.Close();
					running = false;
				}
			}
		}
		
		public bool Setup(int portNumber) {
			Stop();
			lock (socketLock) {
				try {
					socket = new UdpClient(portNumber);
				} catch {}
			}
			bool success;
			if (socket == null) {
				success = false;
			} else {
				success = true;
				running = true;
			}
			return success;
		}
		
		void ReceiveLoop() {
			while (run) {
				bool sleep;
				lock (socketLock) {
					if (socket == null) {
						sleep = true;
					} else {
						if (socket.Available > 0) {
							IPEndPoint ep = new IPEndPoint(IPAddress.Any, 0);
							lock (inputsLock)
								inputs.Enqueue(Encoding.UTF8.GetString(socket.Receive(ref ep)));
							sleep = false;
						} else {
							sleep = true;
						}
					}
				}
				if (sleep)
					Thread.Sleep(1);
			}
			Stop();
		}
	}
}