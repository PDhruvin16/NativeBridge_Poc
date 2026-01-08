package com.mynativebridge

import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReactContextBaseJavaModule
import com.facebook.react.bridge.ReactMethod

class MyNativeModule(reactContext: ReactApplicationContext) :
  ReactContextBaseJavaModule(reactContext) {

  private val cameraDetector = CameraObjectDetector(reactContext)

  override fun getName(): String {
    return "MyNativeModule"
  }

  @ReactMethod
  fun startObjectDetection(promise: Promise) {
    try {
      cameraDetector.start(promise)
    } catch (e: Exception) {
      promise.reject("MODULE_ERROR", "Failed to start detection: ${e.message}")
    }
  }

  @ReactMethod
  fun stopObjectDetection() {
    try {
      cameraDetector.stop()
    } catch (e: Exception) {
      // Silent fail
    }
  }
}