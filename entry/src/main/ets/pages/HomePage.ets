// 首页：1:1 还原原型「中间 App 首页」
import { router, promptAction } from '@kit.ArkUI';
import { StudentInfo, SCHOOL_NAME, PICKUP_PLATE } from '../model/AppModels';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { Store } from '../common/Store';
import { FeatureIcon, StudentAvatar } from '../common/Visuals';
import { NotificationService } from '../common/NotificationService';
import common from '@ohos.app.ability.common';

interface StepState {
  done: boolean;
  current: boolean;
}

@Component
export struct HomePage {
  @StorageLink('studentJson') @Watch('onDataChange') studentJson: string = '{}';
  @StorageLink('flowDoneJson') @Watch('onDataChange') flowDoneJson: string = '[]';
  @StorageLink('ocrState') @Watch('onDataChange') ocrState: string = 'none';
  @StorageLink('pickupDist') @Watch('onDataChange') pickupDist: string = '--';
  @StorageLink('pickupEta') @Watch('onDataChange') pickupEta: string = '--';
  @State st: StudentInfo | null = null;
  @State steps: StepState[] = [];
  @State progress: number = 0;
  @State completedFlowCount: number = 0;
  @State currentTitle: string = '行前准备';
  goTab: (i: number) => void = (i: number) => {};

  aboutToAppear(): void {
    this.refresh();
  }

  onDataChange(): void {
    this.refresh();
  }

  private refresh(): void {
    try {
      this.st = JSON.parse(this.studentJson) as StudentInfo;
    } catch (e) {
      this.st = null;
    }
    let done: string[] = [];
    try {
      done = JSON.parse(this.flowDoneJson) as string[];
    } catch (e) {
      done = [];
    }
    const has = (id: string): boolean => done.indexOf(id) >= 0;
    const profileReady: boolean = this.st !== null && (this.st.studentId ?? '').length > 0 && (this.st.name ?? '').length > 0;
    const s1: boolean = (has('register') && has('info')) || profileReady;
    const s2: boolean = has('ocr') || this.ocrState === 'passed';
    const s3: boolean = has('arrive') || has('arriveCheck') || has('campus');
    const s4: boolean = has('dorm');
    this.steps = [
      { done: s1, current: !s1 },
      { done: s2, current: !s2 && s1 },
      { done: s3, current: !s3 && s2 && s1 },
      { done: s4, current: !s4 && s3 }
    ];
    let cnt: number = 0;
    if (s1) cnt++;
    if (s2) cnt++;
    if (s3) cnt++;
    if (s4) cnt++;
    this.progress = cnt * 25;
    this.completedFlowCount = cnt;
    this.currentTitle = !s1 ? '行前准备' : !s2 ? '证件预审' : !s3 ? '到校报到' : !s4 ? '宿舍入住' : '报到完成';
  }

  private goTile(label: string): void {
    switch (label) {
      case '差异化清单':
        router.pushUrl({ url: 'pages/PackingListPage' });
        break;
      case '证件OCR预审':
        router.pushUrl({ url: 'pages/OcrPrecheckPage' });
        break;
      case '校内导航':
        router.pushUrl({ url: 'pages/MapNavPage' });
        break;
      case '无感接站':
        router.pushUrl({ url: 'pages/PickupCenterPage' });
        break;
      case '报到流程树':
        router.pushUrl({ url: 'pages/FlowTreePage' });
        break;
      case '实时行程提醒':
        this.sendTripReminder();
        break;
      case '消息中心':
        router.pushUrl({ url: 'pages/MessageCenterPage' });
        break;
      case '社交破冰':
        router.pushUrl({ url: 'pages/IceBreakPage' });
        break;
      default:
        break;
    }
  }

  private async sendTripReminder(): Promise<void> {
    const trip = this.st === null ? '尚未登记行程' : `${this.st.transport || '出行'} ${this.st.trainNo || '未填车次'}，预计 ${this.st.arriveTime || '未填时间'} 到达 ${this.st.station || '未填站点'}`;
    try {
      await NotificationService.publish(getContext(this) as common.UIAbilityContext, 2102, '新生行程提醒',
        `${trip}；证件预审${this.ocrState === 'passed' ? '已完成' : '未完成'}，报到进度${this.progress}%`);
      promptAction.showToast({ message: '行程提醒已发送到手机通知栏' });
    } catch (e) {
      promptAction.showToast({ message: '请允许通知权限后重试' });
    }
  }

  private stepIcon(i: number): string {
    if (this.steps.length > i && this.steps[i].done) {
      return 'check';
    }
    return '';
  }

  // 深蓝进度树卡片里的四步节点
  @Builder
  navStep(i: number, label: string) {
    Column({ space: 5 }) {
      Stack() {
        if (this.steps.length > i && this.steps[i].done) {
          Circle({ width: 22, height: 22 }).fill('#7BC98B')
          SvgIcon({ name: 'check', iconSize: 13, color: C.NAVY, strokeWidth: 3 })
        } else if (this.steps.length > i && this.steps[i].current && !this.steps[i].done && i === 2) {
          Circle({ width: 22, height: 22 }).fill(C.CARD)
          SvgIcon({ name: 'chevron', iconSize: 13, color: C.PRIMARY, strokeWidth: 2.6 })
        } else {
          Circle({ width: 22, height: 22 }).fillOpacity(0).stroke('#5B7BA6').strokeWidth(1.5)
        }
      }
      .width(24)
      .height(24)

      Text(label)
        .fontSize(10.5)
        .fontColor(this.steps.length > i && this.steps[i].done ? '#DDE7F2' : '#8FA6C4')
    }
    .width(64)
  }

  @Builder
  gridTile(iconRes: Resource, label: string) {
    Column({ space: 5 }) {
      FeatureIcon({ iconRes: iconRes, iconBox: 64 })
      Text(label).fontSize(11.5).fontColor(C.TEXT).maxLines(1).fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .onClick(() => { this.goTile(label); })
  }

  @Builder
  miniMap() {
    // 校园地图快捷卡片中的迷你地图
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#E8F0E2')
        .borderRadius(10)
      // 地块
      Column()
        .width(52).height(34).backgroundColor('#BFE0C0').borderRadius(5)
        .margin({ left: 12, top: 10 })
      Column()
        .width(40).height(26).backgroundColor('#B9D4F0').borderRadius(5)
        .margin({ left: 78, top: 14 })
      Column()
        .width(46).height(28).backgroundColor('#F2DE9E').borderRadius(5)
        .margin({ left: 22, top: 56 })
      Column()
        .width(44).height(30).backgroundColor('#B9D4F0').borderRadius(5)
        .margin({ left: 96, top: 52 })
      // 道路
      Column().width('100%').height(3).backgroundColor('#FFFFFF').margin({ top: 48 })
      Column().width(3).height('100%').backgroundColor('#FFFFFF').margin({ left: 70 })
      // 标签
      Text('宿舍区').fontSize(8.5).fontColor('#5E8A5E').margin({ left: 16, top: 42 })
      Text('食堂').fontSize(8.5).fontColor('#9C7F2E').margin({ left: 28, top: 82 })
      Text('教学楼').fontSize(8.5).fontColor('#4A7099').margin({ left: 100, top: 80 })
      // 报到点 pin
      Row({ space: 2 }) {
        SvgIcon({ name: 'pin', iconSize: 13, color: C.RED, strokeWidth: 2 })
        Text('报到点').fontSize(8.5).fontColor(C.RED).fontWeight(FontWeight.Medium)
      }
      .margin({ left: 52, top: 22 })
    }
    .width(148)
    .height(104)
    .clip(true)
  }

  build() {
    Scroll() {
      Column() {
        // ===== 顶部用户栏 =====
        Row() {
          StudentAvatar({ name: this.st === null ? '新' : this.st.name, avatarSize: 52 })
          Column({ space: 2 }) {
            if (this.st !== null) {
              Text(this.st.name).fontSize(17).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
              Text(this.st.studentId).fontSize(12).fontColor(C.TEXT_SUB)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 11 })
          Blank()
          Column({ space: 2 }) {
            SvgIcon({ name: 'bell', iconSize: 25, color: C.TEXT, strokeWidth: 2.1 })
            Text('通知').fontSize(9.5).fontColor(C.TEXT_SUB)
          }
          .onClick(() => { router.pushUrl({ url: 'pages/MessageCenterPage' }); })
        }
        .width('100%')
        .padding({ left: 18, right: 18, top: 12, bottom: 10 })
        .margin({ top: -34 })

        // ===== 报到进度树（深蓝卡） =====
        Column() {
          Row() {
            Text('报到进度树').fontSize(15).fontWeight(FontWeight.Medium).fontColor(C.CARD)
            Blank()
            Text(`总进度 ${this.progress}%`).fontSize(11).fontColor('#9DB6D4')
          }
          .width('100%')
          // 四步节点 + 背后连接线（还原原型）
          Stack() {
            Row()
              .width('100%')
              .height(2)
              .backgroundColor('#33547E')
              .margin({ top: 11, left: 32, right: 32 })
            Row() {
              this.navStep(0, '行前准备')
              Blank()
              this.navStep(1, '证件预审')
              Blank()
              this.navStep(2, '到校报到')
              Blank()
              this.navStep(3, '宿舍入住')
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
          }
          .width('100%')
          .margin({ top: 8 })
          Text(`${this.currentTitle}${this.currentTitle === '报到完成' ? '' : '（进行中）'}`)
            .fontSize(12)
            .fontColor(C.CARD)
            .backgroundColor('#3E6493')
            .borderRadius(14)
            .padding({ left: 16, right: 16, top: 6, bottom: 6 })
            .margin({ top: 8 })
            .onClick(() => { router.pushUrl({ url: 'pages/FlowTreePage' }); })
        }
        .alignItems(HorizontalAlign.Center)
        .width('100%')
        .padding({ left: 16, right: 16, top: 13, bottom: 13 })
        .linearGradient({ angle: 135, colors: [[C.NAVY_DARK, 0.0], [C.NAVY, 0.52], ['#248B73', 1.0]] })
        .borderRadius(18)
        .height(142)

        // ===== 功能宫格 4x2 =====
        GridRow({ columns: 4, gutter: 8 }) {
          GridCol({ span: 1 }) { this.gridTile($r('app.media.feature_packing'), '差异化清单') }
          GridCol({ span: 1 }) { this.gridTile($r('app.media.feature_ocr'), '证件OCR预审') }
          GridCol({ span: 1 }) { this.gridTile($r('app.media.feature_map'), '校内导航') }
          GridCol({ span: 1 }) { this.gridTile($r('app.media.feature_bus'), '无感接站') }
          GridCol({ span: 1 }) { this.gridTile($r('app.media.feature_flow'), '报到流程树') }
          GridCol({ span: 1 }) { this.gridTile($r('app.media.feature_reminder'), '实时行程提醒') }
          GridCol({ span: 1 }) { this.gridTile($r('app.media.profile_message'), '消息中心') }
          GridCol({ span: 1 }) { this.gridTile($r('app.media.feature_social'), '社交破冰') }
        }
        .width('100%')
        .margin({ top: 14, bottom: 2 })

        // ===== 快捷卡片区 =====
        Row({ space: 10 }) {
          // 校园地图快捷卡片
          Column({ space: 8 }) {
            this.miniMap()
            Text('校园地图快捷卡片')
              .fontSize(11.5)
              .fontColor(C.TEXT)
              .fontWeight(FontWeight.Medium)
            Text('2D 交互地图 | 点击节点查看实景卡片')
              .fontSize(9.5)
              .fontColor(C.TEXT_SUB)
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding(12)
          .backgroundColor(C.CARD)
          .borderRadius(14)
          .onClick(() => { router.pushUrl({ url: 'pages/MapNavPage' }); })

          // 接站 & 报到进度
          Column({ space: 8 }) {
            Column({ space: 3 }) {
              Text('学校接站车辆').fontSize(11.5).fontWeight(FontWeight.Medium).fontColor(C.TEXT)
              Row({ space: 4 }) {
                SvgIcon({ name: 'bus', iconSize: 14, color: C.PRIMARY, strokeWidth: 1.8 })
                Text('车辆后台未连接').fontSize(10).fontColor(C.TEXT_SUB)
              }
              Text(`距离：${this.pickupDist}   预计 ETA：${this.pickupEta}`).fontSize(10).fontColor(C.TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            Divider().strokeWidth(0.8).color(C.LINE)
            Column({ space: 3 }) {
              Text('报到打卡进度').fontSize(11.5).fontWeight(FontWeight.Medium).fontColor(C.TEXT)
              Row({ space: 4 }) {
                SvgIcon({ name: 'checkcircle', iconSize: 13, color: C.PRIMARY, strokeWidth: 1.8 })
                Text(this.ocrState === 'passed' ? '身份核验 ✓' : '身份核验：未完成').fontSize(10).fontColor(C.TEXT_SUB)
              }
              Row({ space: 4 }) {
                SvgIcon({ name: 'clock', iconSize: 13, color: '#C9A23F', strokeWidth: 1.8 })
                Text(this.completedFlowCount > 0 ? `已完成 ${this.completedFlowCount} 个节点` : '尚无已完成节点').fontSize(10).fontColor(C.TEXT_SUB)
              }
            }
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .padding(12)
          .backgroundColor(C.CARD)
          .borderRadius(14)
          .onClick(() => { router.pushUrl({ url: 'pages/PickupCenterPage' }); })
        }
        .width('100%')
        .margin({ top: 12 })

        Blank().height(16)
        Text(SCHOOL_NAME).fontSize(10.5).fontColor(C.TEXT_HINT)
        Blank().height(10)
      }
      .width('100%')
      .padding({ left: 14, right: 14 })
    }
    .scrollable(ScrollDirection.Vertical)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
    .backgroundColor(C.BG)
  }
}
