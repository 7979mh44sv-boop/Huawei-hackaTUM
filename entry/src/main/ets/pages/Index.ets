@Entry
@Component
struct Index {
  @State message: string = 'Hello World';
  @State heartRate: number = 0;

  build() {
    Column() {
      Text(`Current heart rate: ${this.heartRate} bpm`)

      Button('Start')
        .onClick(() => {
          console.log('Heart rate: ', this.heartRate)
        })
    }
    .height('100%')
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}