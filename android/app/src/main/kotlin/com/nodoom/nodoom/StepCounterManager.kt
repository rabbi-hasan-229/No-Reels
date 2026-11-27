package com.nodoom.nodoom

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.sqrt

/**
 * Hardware step counter for the Emergency Walk Challenge.
 * Uses Sensor.TYPE_STEP_DETECTOR / Sensor.TYPE_STEP_COUNTER when available,
 * and falls back to an accelerometer peak-step detector on devices without a dedicated pedometer.
 */
class StepCounterManager(context: Context) : SensorEventListener {

    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var stepCallback: ((Int) -> Unit)? = null
    private var sessionSteps = 0
    private var initialCounterValue: Float? = null
    private var lastAccelPeakTime = 0L
    private var usingAccelerometerFallback = false

    fun start(onStepUpdated: (Int) -> Unit): Boolean {
        stop()
        sessionSteps = 0
        initialCounterValue = null
        stepCallback = onStepUpdated

        val stepDetector = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        val stepCounter = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        return when {
            stepDetector != null -> {
                usingAccelerometerFallback = false
                sensorManager.registerListener(this, stepDetector, SensorManager.SENSOR_DELAY_UI)
            }
            stepCounter != null -> {
                usingAccelerometerFallback = false
                sensorManager.registerListener(this, stepCounter, SensorManager.SENSOR_DELAY_UI)
            }
            accelerometer != null -> {
                usingAccelerometerFallback = true
                sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_GAME)
            }
            else -> false
        }
    }

    fun stop() {
        try {
            sensorManager.unregisterListener(this)
        } catch (_: Exception) {}
        stepCallback = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        val ev = event ?: return
        when (ev.sensor.type) {
            Sensor.TYPE_STEP_DETECTOR -> {
                if (ev.values.isNotEmpty() && ev.values[0] == 1.0f) {
                    sessionSteps++
                    stepCallback?.invoke(sessionSteps)
                }
            }
            Sensor.TYPE_STEP_COUNTER -> {
                val total = ev.values.firstOrNull() ?: return
                val base = initialCounterValue
                if (base == null) {
                    initialCounterValue = total
                } else {
                    val delta = (total - base).toInt().coerceAtLeast(0)
                    if (delta != sessionSteps) {
                        sessionSteps = delta
                        stepCallback?.invoke(sessionSteps)
                    }
                }
            }
            Sensor.TYPE_ACCELEROMETER -> {
                val x = ev.values[0]
                val y = ev.values[1]
                val z = ev.values[2]
                val magnitude = sqrt((x * x + y * y + z * z).toDouble())
                val now = System.currentTimeMillis()
                // Walking cadence peak threshold (~12.4 m/s^2 with 380ms debounce)
                if (magnitude > 12.4 && now - lastAccelPeakTime > 380L) {
                    lastAccelPeakTime = now
                    sessionSteps++
                    stepCallback?.invoke(sessionSteps)
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
