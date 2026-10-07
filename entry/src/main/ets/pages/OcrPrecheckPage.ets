// 证件 OCR 预审：对准证件四角拍照 → OCR 识别 → 提交核验
// 未接入真实 OCR 服务时绝不伪造识别结果。
import { router, promptAction } from '@kit.ArkUI';
import { StudentInfo } from '../model/AppModels';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { Store } from '../common/Store';
import { picker, fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';

@Component
export struct OcrPrecheckView {
  @StorageLink('studentJson') studentJson: string = '{}';
  @StorageLink('ocrState') @Watch('onOcrChange') ocrState: string = 'none';
  @State docType: string = '录取通知书';
  @State scanning: boolean = false;
  @State captured: boolean = false;
  @State noticeCaptured: boolean = false;
  @State idCaptured: boolean = false;
  @State progress: number = 0;
  @State submitting: boolean = false;
  @State st: StudentInfo | null = null;
  @State recognizedSummary: string = '尚未识别';
  @State ocrName: string = '';
  @State ocrIdNumber: string = '';
  @State ocrAddress: string = '';
  private timerId: number = -1;

  aboutToAppear(): void {
    try {
      this.st = JSON.parse(this.studentJson) as StudentInfo;
      this.ocrName = this.st.name ?? '';
      this.ocrIdNumber = this.st.idNumber ?? '';
      this.ocrAddress = this.st.address ?? '';
    } catch (e) {
      this.st = null;
    }
    if (this.ocrState === 'passed') {
      this.captured = true;
      this.noticeCaptured = true;
      this.idCaptured = true;
    }
  }

  private fillIdentity(content: string): void {
    const nameMatch = content.match(/姓名[:：]?([\u4e00-\u9fa5·]{2,8}?)(?=性[别別]|民族|出生|住址|公民|身份证)/);
    const idMatch = content.match(/[1-9]\d{5}(?:19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{3}[\dXx]/);
    const addressMatch = content.match(/住址[:：]?(.+?)(?=公民身份号码|公民身份|身份证号码|身份证号|$)/);
    if (nameMatch !== null) this.ocrName = nameMatch[1].replace(/性[别別].*$/, '').replace(/[男女]$/, '');
    if (idMatch !== null) this.ocrIdNumber = idMatch[0].toUpperCase();
    if (addressMatch !== null) this.ocrAddress = addressMatch[1].substring(0, Math.min(60, addressMatch[1].length));
    Store.saveStr(Store.K_OCR_DATA, JSON.stringify({ name: this.ocrName, idNumber: this.ocrIdNumber, address: this.ocrAddress }));
  }

  private maskedId(): string {
    if (this.ocrIdNumber.length < 8) return this.ocrIdNumber.length > 0 ? this.ocrIdNumber : '待识别';
    return `${this.ocrIdNumber.substring(0, 6)}********${this.ocrIdNumber.substring(this.ocrIdNumber.length - 4)}`;
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  onOcrChange(): void {
    if (this.ocrState === 'passed') {
      this.captured = true;
      this.noticeCaptured = true;
      this.idCaptured = true;
    }
  }

  private async startScan(): Promise<void> {
    if (this.scanning) return;
    this.scanning = true;
    let source: image.ImageSource | undefined = undefined;
    let pixelMap: image.PixelMap | undefined = undefined;
    let file: fileIo.File | undefined = undefined;
    try {
      const viewPicker = new picker.PhotoViewPicker();
      const options = new picker.PhotoSelectOptions();
      options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = 1;
      const selected = await viewPicker.select(options);
      if (selected.photoUris.length === 0) return;
      file = await fileIo.open(selected.photoUris[0], fileIo.OpenMode.READ_ONLY);
      source = image.createImageSource(file.fd);
      pixelMap = await source.createPixelMap({ desiredPixelFormat: image.PixelMapFormat.RGBA_8888 });
      await textRecognition.init();
      const result = await textRecognition.recognizeText({ pixelMap: pixelMap });
      const content = result.value.replace(/\s/g, '');
      if (this.docType === '录取通知书') {
        this.noticeCaptured = (content.indexOf('录取') >= 0 && content.indexOf('通知') >= 0) ||
          content.indexOf('新生入学') >= 0 || content.indexOf('入学通知') >= 0;
      } else {
        const idMatch: RegExpMatchArray | null = content.match(/[1-9]\d{5}(?:19|20)\d{2}(?:0[1-9]|1[0-2])(?:0[1-9]|[12]\d|3[01])\d{3}[\dXx]/);
        const hasIdentityFields: boolean = content.indexOf('姓名') >= 0 &&
          (content.indexOf('住址') >= 0 || content.indexOf('公民身份') >= 0 || content.indexOf('身份证') >= 0);
        this.idCaptured = idMatch !== null || hasIdentityFields;
        this.fillIdentity(content);
      }
      this.recognizedSummary = content.length > 0 ? `识别到 ${content.length} 个字符：${content.substring(0, Math.min(36, content.length))}${content.length > 36 ? '…' : ''}` : '没有识别到文字，请使用清晰、正向、无遮挡的原图';
      this.captured = this.noticeCaptured && this.idCaptured;
      promptAction.showToast({ message: (this.docType === '录取通知书' ? this.noticeCaptured : this.idCaptured) ? '真实 OCR 识别成功' : '未识别到对应证件关键字段，请重拍' });
    } catch (e) {
      promptAction.showToast({ message: `OCR 识别失败：${(e as Error).message}` });
    } finally {
      this.scanning = false;
      if (pixelMap !== undefined) pixelMap.release();
      if (source !== undefined) source.release();
      if (file !== undefined) await fileIo.close(file);
      await textRecognition.release();
    }
  }

  private submit(): void {
    if (!this.noticeCaptured || !this.idCaptured) {
      promptAction.showToast({ message: `请补齐${this.noticeCaptured ? '身份证' : (this.idCaptured ? '录取通知书' : '录取通知书和身份证')}后再提交` });
      return;
    }
    if (this.st !== null) {
      const cleanName = this.ocrName.replace(/性[别別].*$/, '').replace(/[男女]$/, '').trim();
      if (cleanName.length < 2) {
        promptAction.showToast({ message: '请核对并填写正确姓名' });
        return;
      }
      const next: StudentInfo = {
        name: cleanName,
        studentId: this.st.studentId,
        major: this.st.major,
        hometown: this.st.hometown,
        region: this.st.region,
        dorm: this.st.dorm,
        transport: this.st.transport,
        trainNo: this.st.trainNo,
        arriveTime: this.st.arriveTime,
        station: this.st.station,
        idNumber: this.ocrIdNumber,
        address: this.ocrAddress
      };
      this.st = next;
      Store.saveStudent(next);
      Store.saveStr(Store.K_OCR_DATA, JSON.stringify({ name: cleanName, idNumber: this.ocrIdNumber, address: this.ocrAddress }));
    }
    Store.saveStr(Store.K_OCR, 'passed');
    Store.addFlowDone('ocr');
    promptAction.showToast({ message: '本机真实 OCR 预审通过，结果已保存' });
  }

  @Builder
  corner(posX: Length, posY: Length, flipX: boolean, flipY: boolean) {
    Path()
      .commands(flipY ?
        (flipX ? 'M15 0 L15 12 A3 3 0 0 1 12 15 L0 15' : 'M1 0 L1 12 A3 3 0 0 0 4 15 L16 15') :
        (flipX ? 'M0 1 L12 1 A3 3 0 0 1 15 4 L15 16' : 'M1 16 L1 4 A3 3 0 0 1 4 1 L16 1'))
      .fillOpacity(0)
      .stroke('#FFFFFF')
      .strokeWidth(3)
      .strokeLineCap(LineCapStyle.Round)
      .position({ x: posX, y: posY })
  }

  build() {
    Column() {
      // ===== 取景区（深色） =====
      Column() {
        Row() {
          SvgIcon({ name: 'back', iconSize: 22, color: '#FFFFFF', strokeWidth: 2 })
            .onClick(() => { router.back(); })
          Blank()
          SvgIcon({ name: 'scan', iconSize: 21, color: '#FFFFFF', strokeWidth: 1.8 }).margin({ right: 16 })
          SvgIcon({ name: 'camera', iconSize: 21, color: '#FFFFFF', strokeWidth: 1.8 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })

        Blank()
        // 文档类型切换
        Row() {
          Text('录取通知书')
            .fontSize(14.5)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.docType === '录取通知书' ? '#FFFFFF' : '#99FFFFFF')
            .onClick(() => { this.docType = '录取通知书'; })
          Divider().vertical(true).strokeWidth(1).color('#55FFFFFF').height(18).margin({ left: 20, right: 20 })
          Text('身份证')
            .fontSize(14.5)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.docType === '身份证' ? '#FFFFFF' : '#99FFFFFF')
            .onClick(() => { this.docType = '身份证'; })
        }
        .margin({ bottom: 24 })

        Row({ space: 8 }) {
          Row({ space: 4 }) {
            SvgIcon({ name: this.noticeCaptured ? 'checkcircle' : 'clock', iconSize: 13, color: this.noticeCaptured ? '#7BC98B' : '#AFC0CD', strokeWidth: 2 })
            Text(`录取通知书${this.noticeCaptured ? '已识别' : '待识别'}`).fontSize(10.5).fontColor('#D8E5EA')
          }
          Row({ space: 4 }) {
            SvgIcon({ name: this.idCaptured ? 'checkcircle' : 'clock', iconSize: 13, color: this.idCaptured ? '#7BC98B' : '#AFC0CD', strokeWidth: 2 })
            Text(`身份证${this.idCaptured ? '已识别' : '待识别'}`).fontSize(10.5).fontColor('#D8E5EA')
          }
        }
        .margin({ bottom: 12 })

        // 取景框 + 四角
        Stack({ alignContent: Alignment.Center }) {
          Rect({ width: 250, height: 150 })
            .radiusWidth(10).radiusHeight(10)
            .fill('#22FFFFFF')
            .stroke('#66FFFFFF').strokeWidth(1)
          Stack() {
            this.corner(0, 0, false, false)
            this.corner(234, 0, true, false)
            this.corner(0, 134, false, true)
            this.corner(234, 134, true, true)
            Column({ space: 12 }) {
              Row({ space: 26 }) {
                Column({ space: 6 }) {
                  SvgIcon({ name: 'file', iconSize: 30, color: '#FFFFFF', strokeWidth: 1.6 })
                  Text('录取通知书').fontSize(11.5).fontColor('#DDFFFFFF')
                }
                Divider().vertical(true).strokeWidth(1).color('#55FFFFFF').height(34)
                Column({ space: 6 }) {
                  SvgIcon({ name: 'idcard', iconSize: 30, color: '#FFFFFF', strokeWidth: 1.6 })
                  Text('身份证').fontSize(11.5).fontColor('#DDFFFFFF')
                }
              }
              Text('对准证件四角拍照').fontSize(12).fontColor('#99FFFFFF')
              if (this.scanning) {
                Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
                  .width(150).height(5).color('#7BC98B').backgroundColor('#33FFFFFF')
                Text(`OCR 识别中 ${this.progress}%`).fontSize(10.5).fontColor('#7BC98B')
              }
            }
          }
          .width(250)
          .height(150)
        }
        .onClick(() => { this.startScan(); })

        Text(this.recognizedSummary).fontSize(10.5).fontColor('#BFD0D8').width('82%').maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).margin({ top: 10 })

        Blank()
        Button(this.captured ? '重新识别' : (this.scanning ? '识别中…' : '拍 照 识 别'))
          .width('72%').height(44)
          .backgroundColor(this.scanning ? '#4A6B4F' : C.PRIMARY)
          .fontSize(16)
          .margin({ bottom: 30 })
          .onClick(() => { this.startScan(); })
      }
      .width('100%')
      .height(420)
      .backgroundColor('#111417')

      // ===== 底部信息单 =====
      Column({ space: 12 }) {
        Row({ space: 12 }) {
          Stack() {
            Circle({ width: 58, height: 58 }).fill('#DDE6F0')
            SvgIcon({ name: 'user', iconSize: 32, color: '#7C8FA8', strokeWidth: 2 })
          }
          Column({ space: 4 }) {
            if (this.st !== null) {
              Text('OCR 已自动回填，请人工核对后提交').fontSize(11).fontColor(C.PRIMARY).margin({ bottom: 4 })
              Row({ space: 6 }) {
                Text('姓名').fontSize(12).fontColor(C.TEXT_SUB).width(46)
                TextInput({ text: this.ocrName || this.st.name, placeholder: '请输入姓名' }).layoutWeight(1).height(36)
                  .fontSize(13).fontColor('#111111').placeholderColor('#8B929B').caretColor(C.PRIMARY)
                  .backgroundColor('#F2F4F6').borderRadius(8)
                  .onChange((v: string) => { this.ocrName = v.replace(/性[别別].*$/, '').replace(/[男女]$/, ''); })
              }.width('100%')
              Text(`学号：${this.st.studentId}`).fontSize(13.5).fontColor(C.TEXT)
              Row({ space: 6 }) {
                Text('身份证').fontSize(12).fontColor(C.TEXT_SUB).width(46)
                TextInput({ text: this.ocrIdNumber, placeholder: '识别后可手动修正' }).layoutWeight(1).height(36)
                  .fontSize(12).fontColor('#111111').placeholderColor('#8B929B').caretColor(C.PRIMARY)
                  .backgroundColor('#F2F4F6').borderRadius(8)
                  .onChange((v: string) => { this.ocrIdNumber = v.toUpperCase(); })
              }.width('100%')
              Row({ space: 6 }) {
                Text('住址').fontSize(12).fontColor(C.TEXT_SUB).width(46)
                TextInput({ text: this.ocrAddress, placeholder: '识别后可手动修正' }).layoutWeight(1).height(36)
                  .fontSize(12).fontColor('#111111').placeholderColor('#8B929B').caretColor(C.PRIMARY)
                  .backgroundColor('#F2F4F6').borderRadius(8)
                  .onChange((v: string) => { this.ocrAddress = v; })
              }.width('100%')
              Text(`录取专业：${this.st.major}`).fontSize(13.5).fontColor(C.TEXT)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(C.CARD)
        .borderRadius(14)

        // 状态
        if (this.ocrState === 'none') {
          Row({ space: 6 }) {
            SvgIcon({ name: 'clock', iconSize: 15, color: '#9AA0A8', strokeWidth: 2 })
            Text('未提交').fontSize(12.5).fontColor('#9AA0A8')
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
        } else if (this.ocrState === 'submitted' || this.submitting) {
          Row({ space: 8 }) {
            LoadingProgress().width(18).height(18).color(C.PRIMARY)
            Text('审核中…').fontSize(12.5).fontColor(C.TEXT_SUB)
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
        } else {
          Row({ space: 6 }) {
            SvgIcon({ name: 'checkcircle', iconSize: 16, color: C.PRIMARY, strokeWidth: 2 })
            Text('审核通过').fontSize(12.5).fontColor(C.PRIMARY).fontWeight(FontWeight.Medium)
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
        }

        Button(this.ocrState === 'passed' ? '已完成核验' : '确 认 提 交')
          .width('100%').height(46)
          .backgroundColor(this.ocrState === 'passed' ? '#B9C2CC' : C.PRIMARY)
          .fontSize(16)
          .onClick(() => { this.submit(); })
      }
      .width('100%')
      .padding(16)
      .backgroundColor(C.BG)
      .borderRadius({ topLeft: 18, topRight: 18 })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.BG)
  }
}

@Entry
@Component
struct OcrPrecheckPage {
  build() {
    Column() {
      OcrPrecheckView()
    }
    .width('100%')
    .height('100%')
  }
}
