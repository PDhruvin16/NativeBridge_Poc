package com.mynativebridge

import android.annotation.SuppressLint
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.facebook.react.bridge.*
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.objects.ObjectDetection
import com.google.mlkit.vision.objects.defaults.ObjectDetectorOptions
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class CameraObjectDetector(
  private val reactContext: ReactApplicationContext
) {

  private val executor = Executors.newSingleThreadExecutor()
  private var previewView: PreviewView? = null
  private var cameraProvider: ProcessCameraProvider? = null
  private val hasResolvedPromise = AtomicBoolean(false)
  private var frameCount = 0
  private val MIN_CONFIDENCE = 0.5 // Minimum confidence threshold

  private val detector by lazy {
    val options = ObjectDetectorOptions.Builder()
      .setDetectorMode(ObjectDetectorOptions.STREAM_MODE)
      .enableMultipleObjects()
      .enableClassification()
      .build()

    ObjectDetection.getClient(options)
  }

  @SuppressLint("UnsafeOptInUsageError")
  fun start(promise: Promise) {
    val currentActivity = reactContext.currentActivity
    
    if (currentActivity == null) {
      promise.reject("NO_ACTIVITY", "Activity not found")
      return
    }

    val lifecycleOwner = currentActivity as? LifecycleOwner
    
    if (lifecycleOwner == null) {
      promise.reject("NO_LIFECYCLE", "Activity is not a LifecycleOwner")
      return
    }

    // Reset state
    hasResolvedPromise.set(false)
    frameCount = 0

    // Create PreviewView on UI thread
    UiThreadUtil.runOnUiThread {
      try {
        previewView = PreviewView(reactContext).apply {
          layoutParams = FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
          )
        }

        val contentView = currentActivity.findViewById<ViewGroup>(android.R.id.content)
        contentView?.addView(previewView)

      } catch (e: Exception) {
        promise.reject("PREVIEW_ERROR", "Failed to create preview: ${e.message}")
        return@runOnUiThread
      }
    }

    // Wait for preview to be ready
    Thread.sleep(300)

    val providerFuture = ProcessCameraProvider.getInstance(reactContext)

    providerFuture.addListener({
      try {
        cameraProvider = providerFuture.get()

        // Preview
        val preview = Preview.Builder()
          .build()
          .also {
            it.setSurfaceProvider(previewView?.surfaceProvider)
          }

        // Image Analysis
        val analysis = ImageAnalysis.Builder()
          .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
          .build()

        analysis.setAnalyzer(executor) { imageProxy ->
          if (hasResolvedPromise.get()) {
            imageProxy.close()
            return@setAnalyzer
          }

          frameCount++

          val mediaImage = imageProxy.image

          if (mediaImage == null) {
            imageProxy.close()
            return@setAnalyzer
          }

          val image = InputImage.fromMediaImage(
            mediaImage,
            imageProxy.imageInfo.rotationDegrees
          )

          detector.process(image)
            .addOnSuccessListener { objects ->
              
              // Filter valid objects with good confidence
              val validObjects = objects.filter { obj ->
                val label = obj.labels.firstOrNull()
                label != null && 
                label.text != "Unknown" && 
                label.confidence >= MIN_CONFIDENCE
              }

              android.util.Log.d("CameraDetector", "Frame $frameCount: Total=${objects.size}, Valid=${validObjects.size}")

              // If we have valid objects, resolve immediately
              if (validObjects.isNotEmpty() && !hasResolvedPromise.get()) {
                
                val result = Arguments.createArray()

                for (obj in validObjects) {
                  val label = obj.labels.firstOrNull()
                  if (label != null) {
                    val map = Arguments.createMap()
                    map.putString("label", label.text)
                    map.putDouble("confidence", label.confidence.toDouble())
                    result.pushMap(map)
                    
                    android.util.Log.d("CameraDetector", "Detected: ${label.text} (${label.confidence})")
                  }
                }

                if (hasResolvedPromise.compareAndSet(false, true)) {
                  promise.resolve(result)
                }
              }
              
              // After 60 frames (~4 seconds), return whatever we have
              if (frameCount >= 60 && !hasResolvedPromise.get()) {
                if (hasResolvedPromise.compareAndSet(false, true)) {
                  android.util.Log.d("CameraDetector", "Timeout: No valid objects found")
                  promise.resolve(Arguments.createArray())
                }
              }
            }
            .addOnFailureListener { error ->
              android.util.Log.e("CameraDetector", "Detection failed", error)
              if (!hasResolvedPromise.get()) {
                if (hasResolvedPromise.compareAndSet(false, true)) {
                  promise.reject("DETECT_FAIL", error.message)
                }
              }
            }
            .addOnCompleteListener {
              imageProxy.close()
            }
        }

        cameraProvider?.unbindAll()
        cameraProvider?.bindToLifecycle(
          lifecycleOwner,
          CameraSelector.DEFAULT_BACK_CAMERA,
          preview,
          analysis
        )

      } catch (e: Exception) {
        android.util.Log.e("CameraDetector", "Camera error", e)
        promise.reject("CAMERA_ERROR", "Camera initialization failed: ${e.message}")
      }
    }, ContextCompat.getMainExecutor(reactContext))
  }

  fun stop() {
    UiThreadUtil.runOnUiThread {
      try {
        android.util.Log.d("CameraDetector", "Stopping camera")
        
        cameraProvider?.unbindAll()
        
        val activity = reactContext.currentActivity
        if (activity != null) {
          val contentView = activity.findViewById<ViewGroup>(android.R.id.content)
          contentView?.removeView(previewView)
        }
        
        previewView = null
        cameraProvider = null
        hasResolvedPromise.set(false)
        frameCount = 0
        
      } catch (e: Exception) {
        android.util.Log.e("CameraDetector", "Stop error", e)
      }
    }
  }
}