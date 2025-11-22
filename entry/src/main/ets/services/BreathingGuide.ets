import { vibrator } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'BreathingGuide';

// Breathing pattern returned by LLM
export interface BreathingPattern {
  inhaleMs: number;      // Duration to inhale (vibration off)
  holdMs: number;        // Duration to hold breath
  exhaleMs: number;      // Duration to exhale (gentle vibration)
  cycles: number;        // Number of breath cycles
  message: string;       // Guidance message for UI
}

// Sensor data to send to LLM for analysis
export interface SensorSnapshot {
  heartRate: number;
  heartRateBaseline: number;
  isMoving: boolean;
  accelMagnitude: number;
  // Future sensors:
  // fatigue?: number;
  // sweatLevel?: number;
  // skinTemp?: number;
}

// Default pattern (used before LLM integration)
const DEFAULT_PATTERN: BreathingPattern = {
  inhaleMs: 4000,   // 4 seconds inhale
  holdMs: 2000,     // 2 seconds hold
  exhaleMs: 6000,   // 6 seconds exhale
  cycles: 3,        // 3 breath cycles
  message: 'Take a deep breath...'
};

class BreathingGuideClass {
  private isRunning: boolean = false;
  private currentCycle: number = 0;

  /**
   * TODO: Integrate LLM to analyze sensor data and return personalized breathing pattern
   *
   * The LLM should consider:
   * - Current heart rate vs baseline (stress intensity)
   * - Movement level (stationary = more stressed?)
   * - Future: fatigue indicators, sweat level, skin temperature
   *
   * Returns a BreathingPattern optimized for the user's current state
   */
  async getBreathingPatternFromLLM(sensors: SensorSnapshot): Promise<BreathingPattern> {
    hilog.info(DOMAIN, TAG, 'Analyzing sensors: HR=%{public}d, baseline=%{public}d, moving=%{public}s',
      sensors.heartRate, sensors.heartRateBaseline, sensors.isMoving ? 'yes' : 'no');

    // ============================================================
    // TODO: Replace with actual LLM API call
    // ============================================================
    // Example prompt structure:
    // "User heart rate is {hr} bpm (baseline: {baseline}).
    //  They are {moving/stationary}. Acceleration: {accel} m/s².
    //  Recommend a breathing pattern (inhale/hold/exhale in seconds)
    //  and number of cycles to help reduce stress."
    // ============================================================

    // For now, return adaptive pattern based on simple rules
    const stressIntensity = sensors.heartRate - sensors.heartRateBaseline;

    if (stressIntensity > 30) {
      // High stress - longer exhale, more cycles
      return {
        inhaleMs: 4000,
        holdMs: 2000,
        exhaleMs: 8000,
        cycles: 5,
        message: 'High stress detected. Deep breathing...'
      };
    } else if (stressIntensity > 15) {
      // Moderate stress
      return {
        inhaleMs: 4000,
        holdMs: 2000,
        exhaleMs: 6000,
        cycles: 4,
        message: 'Elevated heart rate. Relax...'
      };
    }

    return DEFAULT_PATTERN;
  }

  /**
   * Start guided breathing with vibration feedback
   * - Vibrate briefly at start of each phase
   * - Pattern: inhale (no vibration) -> hold -> exhale (gentle pulse)
   */
  async startGuidedBreathing(pattern: BreathingPattern): Promise<void> {
    if (this.isRunning) {
      hilog.warn(DOMAIN, TAG, 'Breathing guide already running');
      return;
    }

    this.isRunning = true;
    this.currentCycle = 0;
    hilog.info(DOMAIN, TAG, 'Starting breathing guide: %{public}d cycles', pattern.cycles);

    for (let i = 0; i < pattern.cycles && this.isRunning; i++) {
      this.currentCycle = i + 1;

      // Inhale signal - short vibration
      await this.vibrate(200);
      await this.sleep(pattern.inhaleMs);

      // Hold signal - double tap
      await this.vibrate(100);
      await this.sleep(100);
      await this.vibrate(100);
      await this.sleep(pattern.holdMs);

      // Exhale signal - long gentle vibration
      await this.vibrate(300);
      await this.sleep(pattern.exhaleMs);
    }

    this.isRunning = false;
    hilog.info(DOMAIN, TAG, 'Breathing guide completed');
  }

  /**
   * Trigger vibration with specified duration
   */
  private async vibrate(durationMs: number): Promise<void> {
    try {
      await vibrator.startVibration({
        type: 'time',
        duration: durationMs
      }, {
        usage: 'alarm'
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Vibration failed: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * Simple sleep helper
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Stop current breathing session
   */
  stop(): void {
    this.isRunning = false;
    hilog.info(DOMAIN, TAG, 'Breathing guide stopped');
  }

  /**
   * Get current cycle number (for UI progress)
   */
  getCurrentCycle(): number {
    return this.currentCycle;
  }

  /**
   * Check if breathing guide is active
   */
  isActive(): boolean {
    return this.isRunning;
  }

  /**
   * Quick stress alert - single vibration burst
   * Used for immediate notification before starting guided breathing
   */
  async alertStress(): Promise<void> {
    await this.vibrate(500);
  }
}

// Export singleton instance
export const BreathingGuide = new BreathingGuideClass();
