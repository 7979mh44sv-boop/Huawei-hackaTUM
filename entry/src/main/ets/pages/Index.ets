import { StressDetector, StressState } from '../services/StressDetector';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'StressWatch';

@Entry
@Component
struct Index {
  @State heartRate: number = 0;
  @State stressState: StressState = 'NORMAL';
  @State isMonitoring: boolean = false;
  @State statusMessage: string = 'Tap to start';
  @State accelMagnitude: number = 0;
  @State speed: number = 0;

  aboutToAppear(): void {
    hilog.info(DOMAIN, TAG, 'Index page appearing');

    // Set up state change callback
    StressDetector.setOnStateChange((state: StressState, hr: number) => {
      this.heartRate = hr;
      this.stressState = state;
      this.accelMagnitude = StressDetector.getAccelMagnitude();
      this.speed = StressDetector.getSpeed();
      this.updateStatusMessage();
    });
  }

  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, 'Index page disappearing');
    this.stopMonitoring();
  }

  private updateStatusMessage(): void {
    switch (this.stressState) {
      case 'NORMAL':
        this.statusMessage = this.isMonitoring ? 'Monitoring...' : 'Tap to start';
        break;
      case 'CHECKING':
        this.statusMessage = 'Analyzing...';
        break;
      case 'EXERCISE':
        this.statusMessage = 'Exercise detected';
        break;
      case 'STRESS':
        this.statusMessage = 'Stress detected!';
        break;
    }
  }

  private async startMonitoring(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Starting monitoring');
    this.isMonitoring = true;
    this.statusMessage = 'Starting sensors...';

    await StressDetector.startAll();

    if (StressDetector.isActive()) {
      this.statusMessage = 'Monitoring...';
    } else {
      this.statusMessage = 'Sensor unavailable';
      this.isMonitoring = false;
    }
  }

  private stopMonitoring(): void {
    hilog.info(DOMAIN, TAG, 'Stopping monitoring');
    StressDetector.stopAll();
    this.isMonitoring = false;
    this.statusMessage = 'Tap to start';
  }

  private toggleMonitoring(): void {
    if (this.isMonitoring) {
      this.stopMonitoring();
    } else {
      this.startMonitoring();
    }
  }

  private dismissAlert(): void {
    StressDetector.dismissStressAlert();
  }

  // Get background color based on state
  private getBackgroundColor(): ResourceColor {
    switch (this.stressState) {
      case 'NORMAL':
        return '#1A1A2E';  // Dark blue
      case 'CHECKING':
        return '#2D2D44';  // Slightly lighter
      case 'EXERCISE':
        return '#1A3A2E';  // Dark green
      case 'STRESS':
        return '#3A1A1A';  // Dark red
      default:
        return '#1A1A2E';
    }
  }

  // Get accent color based on state
  private getAccentColor(): ResourceColor {
    switch (this.stressState) {
      case 'NORMAL':
        return '#4ECDC4';  // Teal
      case 'CHECKING':
        return '#FFE66D';  // Yellow
      case 'EXERCISE':
        return '#95E1A3';  // Light green
      case 'STRESS':
        return '#FF6B6B';  // Red
      default:
        return '#4ECDC4';
    }
  }

  // Get HR display color
  private getHRColor(): ResourceColor {
    if (this.heartRate === 0) return '#666666';
    if (this.heartRate > 100) return '#FF6B6B';
    if (this.heartRate > 80) return '#FFE66D';
    return '#4ECDC4';
  }

  build() {
    Stack() {
      // Circular background for watch face
      Circle()
        .width('100%')
        .height('100%')
        .fill(this.getBackgroundColor())

      // Outer ring indicator
      Circle()
        .width('95%')
        .height('95%')
        .fill(Color.Transparent)
        .stroke(this.getAccentColor())
        .strokeWidth(4)

      // Main content column
      Column() {
        // Status indicator at top
        Text(this.stressState)
          .fontSize(12)
          .fontColor(this.getAccentColor())
          .fontWeight(FontWeight.Medium)
          .margin({ top: 20 })

        Blank()
          .height(10)

        // Large heart rate display
        Row() {
          Text(this.heartRate > 0 ? this.heartRate.toString() : '--')
            .fontSize(56)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getHRColor())

          Column() {
            // Heart icon or indicator
            Text('\u2665')  // Heart symbol
              .fontSize(20)
              .fontColor(this.getHRColor())

            Text('BPM')
              .fontSize(12)
              .fontColor('#AAAAAA')
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 8 })
        }
        .alignItems(VerticalAlign.Center)

        // Status message
        Text(this.statusMessage)
          .fontSize(14)
          .fontColor('#CCCCCC')
          .margin({ top: 8 })

        Blank()
          .height(15)

        // Action button or stress dismiss
        if (this.stressState === 'STRESS') {
          Button('Dismiss')
            .width(100)
            .height(36)
            .fontSize(14)
            .backgroundColor('#FF6B6B')
            .fontColor(Color.White)
            .borderRadius(18)
            .onClick(() => this.dismissAlert())
        } else {
          Button(this.isMonitoring ? 'Stop' : 'Start')
            .width(100)
            .height(36)
            .fontSize(14)
            .backgroundColor(this.isMonitoring ? '#666666' : this.getAccentColor())
            .fontColor(this.isMonitoring ? '#CCCCCC' : '#1A1A2E')
            .borderRadius(18)
            .onClick(() => this.toggleMonitoring())
        }

        // Debug info (can be removed in production)
        if (this.isMonitoring) {
          Column() {
            Text(`Accel: ${this.accelMagnitude.toFixed(2)} m/s²`)
              .fontSize(10)
              .fontColor('#666666')

            Text(`Speed: ${this.speed.toFixed(1)} m/s`)
              .fontSize(10)
              .fontColor('#666666')
          }
          .margin({ top: 10 })
        }
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
