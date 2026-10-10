// 基本信息管理：修改后差异化清单自动重新生成
import { router, promptAction } from '@kit.ArkUI';
import { StudentInfo } from '../model/AppModels';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { Store } from '../common/Store';

// ===== 信息管理页 =====
@Entry
@Component
struct EditProfilePage {
  @StorageLink('studentJson') studentJson: string = '{}';
  @State st: StudentInfo | null = null;
  @State nameV: string = '';
  @State majorV: string = '';
  @State hometownV: string = '';
  @State dormV: string = '';
  @State trainNoV: string = '';
  @State arriveTimeV: string = '';
  private majors: string[] = ['计算机科学', '软件工程', '人工智能', '数据科学', '视觉传达设计', '美术学', '临床医学', '护理学', '工商管理', '英语'];
  private dorms: string[] = ['宿舍12号楼', '宿舍6号楼', '宿舍8号楼', '宿舍15号楼', '研究生公寓'];

  aboutToAppear(): void {
    try {
      this.st = JSON.parse(this.studentJson) as StudentInfo;
    } catch (e) {
      this.st = null;
    }
    if (this.st !== null) {
      this.nameV = this.st.name;
      this.majorV = this.st.major;
      this.hometownV = this.st.hometown;
      this.dormV = this.st.dorm;
      this.trainNoV = this.st.trainNo;
      this.arriveTimeV = this.st.arriveTime;
    }
  }

  private save(): void {
    if (this.st === null) {
      return;
    }
    if (this.nameV.trim().length === 0) {
      promptAction.showToast({ message: '姓名不能为空' });
      return;
    }
    const next: StudentInfo = {
      name: this.nameV.trim(),
      studentId: this.st.studentId,
      major: this.majorV,
      hometown: this.hometownV,
      region: this.st.region,
      dorm: this.dormV,
      transport: this.st.transport,
      trainNo: this.trainNoV,
      arriveTime: this.arriveTimeV,
      station: this.st.station,
      idNumber: this.st.idNumber ?? '',
      address: this.st.address ?? ''
    };
    Store.saveStudent(next);
    promptAction.showToast({ message: '已保存，差异化清单已同步更新' });
    router.back();
  }

  private toOpts(arr: string[]): SelectOption[] {
    const out: SelectOption[] = [];
    for (const v of arr) {
      out.push({ value: v });
    }
    return out;
  }

  build() {
    Column() {
      Row() {
        SvgIcon({ name: 'back', iconSize: 22, color: C.TEXT, strokeWidth: 2 })
          .onClick(() => { router.back(); })
          .margin({ right: 12 })
        Text('基本信息管理').fontSize(18).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 12 }) {
          this.field('姓名', this.nameV, (v: string) => { this.nameV = v; }, false)
          Column({ space: 6 }) {
            Text('专业').fontSize(13).fontColor(C.TEXT_SUB)
            Select(this.toOpts(this.majors))
              .value(this.majorV).font({ size: 14 }).height(42).width('100%')
              .onSelect((i: number) => { this.majorV = this.majors[i]; })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          this.field('生源地', this.hometownV, (v: string) => { this.hometownV = v; }, false)
          Column({ space: 6 }) {
            Text('宿舍楼').fontSize(13).fontColor(C.TEXT_SUB)
            Select(this.toOpts(this.dorms))
              .value(this.dormV).font({ size: 14 }).height(42).width('100%')
              .onSelect((i: number) => { this.dormV = this.dorms[i]; })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          this.field('车次/航班', this.trainNoV, (v: string) => { this.trainNoV = v; }, false)
          this.field('预计到达时间', this.arriveTimeV, (v: string) => { this.arriveTimeV = v; }, false)

          Text('提示：修改专业或生源地后，差异化行李清单将按新信息重新生成。')
            .fontSize(11).fontColor(C.TEXT_HINT)

          Button('保 存')
            .width('100%').height(46)
            .backgroundColor(C.PRIMARY).fontSize(16)
            .margin({ top: 8 })
            .onClick(() => { this.save(); })
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.BG)
  }

  @Builder
  field(label: string, val: string, onChange: (v: string) => void, isPwd: boolean) {
    Column({ space: 6 }) {
      Text(label).fontSize(13).fontColor(C.TEXT_SUB)
      TextInput({ text: val })
        .type(isPwd ? InputType.Password : InputType.Normal)
        .height(42)
        .fontSize(14.5)
        .backgroundColor(C.CARD)
        .borderRadius(10)
        .onChange((v: string) => { onChange(v); })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
