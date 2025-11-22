import { sensor } from '@kit.SensorServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'StressDetector';

// Detection thresholds
const HR_HIGH_THRESHOLD = 100;  // bpm considered elevated
const HR_SPIKE_DELTA = 20;      // sudden jump from baseline
const HR_BUFFER_SIZE = 5;       // rolling average window

export type StressState = 'NORMAL' | 'CHECKING' | 'EXERCISE' | 'STRESS';

// Callback type for state changes
export type StateChangeCallback = (state: StressState, hr: number) => void;

class StressDetectorClass {
  private heartRate: number = 0;
  private hrBuffer: number[] = [];
  private state: StressState = 'NORMAL';
  private isRunning: boolean = false;
  private onStateChange: StateChangeCallback | null = null;

  // Get current heart rate
  getHeartRate(): number {
    return this.heartRate;
  }

  // Get current state
  getState(): StressState {
    return this.state;
  }

  // Set callback for state changes
  setOnStateChange(callback: StateChangeCallback): void {
    this.onStateChange = callback;
  }

  // Calculate baseline from rolling buffer
  private getBaseline(): number {
    if (this.hrBuffer.length === 0) return 0;
    const sum = this.hrBuffer.reduce((a, b) => a + b, 0);
    return sum / this.hrBuffer.length;
  }

  // Check if HR is elevated (high or spiking)
  isElevated(): boolean {
    const baseline = this.getBaseline();
    const isHigh = this.heartRate > HR_HIGH_THRESHOLD;
    const isSpike = baseline > 0 && (this.heartRate - baseline) > HR_SPIKE_DELTA;
    return isHigh || isSpike;
  }

  // Add HR reading to buffer
  private addToBuffer(hr: number): void {
    this.hrBuffer.push(hr);
    if (this.hrBuffer.length > HR_BUFFER_SIZE) {
      this.hrBuffer.shift();
    }
  }

  // Update state and notify
  private updateState(newState: StressState): void {
    if (this.state !== newState) {
      this.state = newState;
      hilog.info(DOMAIN, TAG, 'State changed to: %{public}s, HR: %{public}d', newState, this.heartRate);
      if (this.onStateChange) {
        this.onStateChange(newState, this.heartRate);
      }
    }
  }

  // Handle new HR reading
  private onHeartRateData(hr: number): void {
    this.heartRate = hr;
    this.addToBuffer(hr);
    hilog.debug(DOMAIN, TAG, 'HR: %{public}d, baseline: %{public}d', hr, Math.round(this.getBaseline()));

    // Notify callback even for normal readings (for UI updates)
    if (this.onStateChange) {
      this.onStateChange(this.state, this.heartRate);
    }

    // Check if elevated - actual stress detection happens in evaluateStress()
    if (this.isElevated()) {
      this.updateState('CHECKING');
    } else {
      this.updateState('NORMAL');
    }
  }

  // Start HR monitoring
  start(): void {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'Already running');
      return;
    }

    try {
      sensor.on(sensor.SensorId.HEART_RATE, (data) => {
        if (data && data.heartRate > 0) {
          this.onHeartRateData(data.heartRate);
        }
      }, { interval: 2000000000 }); // 2 seconds in nanoseconds

      this.isRunning = true;
      hilog.info(DOMAIN, TAG, 'HR sensor started');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to start HR sensor: %{public}s', JSON.stringify(err));
    }
  }

  // Stop HR monitoring
  stop(): void {
    if (!this.isRunning) return;

    try {
      sensor.off(sensor.SensorId.HEART_RATE);
      this.isRunning = false;
      hilog.info(DOMAIN, TAG, 'HR sensor stopped');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to stop HR sensor: %{public}s', JSON.stringify(err));
    }
  }

  // Mark as exercise (called from motion/GPS check)
  setExercise(): void {
    this.updateState('EXERCISE');
  }

  // Mark as stress (called from motion/GPS check)
  setStress(): void {
    this.updateState('STRESS');
  }

  // Reset to normal
  reset(): void {
    this.updateState('NORMAL');
  }
}

// Export singleton instance
export const StressDetector = new StressDetectorClass();
