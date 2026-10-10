// 报道流程树：进度环 + 树状节点 + 刷新/跳转导航
import { router, promptAction, AlertDialog } from '@kit.ArkUI';
import { FlowNode } from '../model/AppModels';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { Store } from '../common/Store';

@Component
export struct FlowTreeView {
  @StorageLink('flowDoneJson') @Watch('onFlowChange') flowDoneJson: string = '[]';
  @StorageLink('ocrState') ocrState: string = 'none';
  @State nodes: FlowNode[] = [];
  @State doneCnt: number = 0;
  @State totalCnt: number = 7;
  private currentId: string = 'arrive';

  aboutToAppear(): void {
    this.rebuild();
  }

  onFlowChange(): void {
    this.rebuild();
  }

  // 节点完成判定
  private isDone(id: string, done: string[]): boolean {
    if (done.indexOf(id) >= 0) {
      return true;
    }
    if (id === 'ocr') {
      return this.ocrState === 'passed';
    }
    return false;
  }

  private rebuild(): void {
    let done: string[] = [];
    try {
      done = JSON.parse(this.flowDoneJson) as string[];
    } catch (e) {
      done = [];
    }
    const defs: FlowNode[] = [
      { id: 'register', title: '注册登录', level: 0, done: this.isDone('register', done), note: '' },
      { id: 'info', title: '录入信息', level: 0, done: this.isDone('info', done), note: '' },
      { id: 'ocr', title: 'OCR 证件预审', level: 0, done: this.isDone('ocr', done), note: '' },
      { id: 'bind', title: '行程绑定', level: 0, done: this.isDone('bind', done), note: '' },
      { id: 'arrive', title: '到校打卡 - 迎新专线大巴接站', level: 0, done: this.isDone('arrive', done), note: 'current' },
      { id: 'stationCheck', title: '车站核验', level: 1, done: this.isDone('stationCheck', done), note: '' },
      { id: 'busTrack', title: '大巴轨迹追踪（Timer 模拟场景）', level: 1, done: this.isDone('arriveCheck', done) || this.isDone('arrive', done), note: '' },
      { id: 'arriveCheck', title: '到校核验', level: 1, done: this.isDone('arriveCheck', done), note: '' },
      { id: 'campus', title: '校内报到 - 路线导航引导', level: 0, done: this.isDone('campus', done), note: '' },
      { id: 'materials', title: '领取材料', level: 0, done: this.isDone('materials', done), note: '' },
      { id: 'dorm', title: '宿舍入住', level: 0, done: this.isDone('dorm', done), note: '' }
    ];
    this.nodes = defs;
    // 计算当前节点：第一个未完成的顶层节点
    this.currentId = 'dorm';
    for (const n of defs) {
      if (n.level === 0 && !n.done) {
        this.currentId = n.id;
        break;
      }
    }
    // 进度统计（7 个关键节点）
    const mile: string[] = ['register', 'info', 'ocr', 'bind', 'arrive', 'campus', 'dorm'];
    let cnt: number = 0;
    for (const m of mile) {
      if (this.isDone(m, done)) {
        cnt++;
      }
    }
    this.doneCnt = cnt;
  }

  private percent(): number {
    return Math.round(this.doneCnt * 100 / this.totalCnt);
  }

  private refreshFlow(): void {
    this.rebuild();
    promptAction.showToast({ message: `流程已刷新：${this.doneCnt}/${this.totalCnt} 节点已完成` });
  }

  private onNodeClick(n: FlowNode): void {
    if (n.id === 'ocr' && !n.done) {
      router.pushUrl({ url: 'pages/OcrPrecheckPage' });
      return;
    }
    if (n.id === 'arrive' || n.id === 'busTrack') {
      router.pushUrl({ url: 'pages/PickupCenterPage' });
      return;
    }
    if (n.id === 'campus') {
      router.pushUrl({ url: 'pages/MapNavPage' });
      return;
    }
    if (n.done) {
      promptAction.showToast({ message: `「${n.title}」已完成` });
      return;
    }
    // 手动确认完成（持久化，进度随之刷新）
    this.getUIContext().showAlertDialog({
      title: '完成节点确认',
      message: `确认「${n.title}」已完成吗？确认后流程树与总进度将同步更新。`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确认完成',
        fontColor: C.PRIMARY,
        action: () => {
          Store.addFlowDone(n.id);
          promptAction.showToast({ message: `「${n.title}」已标记完成` });
        }
      }
    });
  }

  build() {
    Column() {
      Row() {
        SvgIcon({ name: 'back', iconSize: 22, color: C.TEXT, strokeWidth: 2 })
          .onClick(() => { router.back(); })
          .margin({ right: 12 })
        Text('报道流程树').fontSize(18).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
        Blank()
        Text(`当前节点：${this.currentId === 'arrive' ? '到校打卡' : this.currentId === 'campus' ? '校内报到' : this.currentId === 'dorm' ? '宿舍入住' : '进行中'}`)
          .fontSize(11).fontColor(C.TEXT_SUB)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 10 })

      Scroll() {
        Column() {
          // 进度环卡片
          Row({ space: 16 }) {
            Stack() {
              Progress({ value: this.percent(), total: 100, type: ProgressType.Ring })
                .width(74).height(74)
                .color(C.TEAL)
                .backgroundColor('#E2E8ED')
                .style({ strokeWidth: 8 })
              SvgIcon({ name: 'check', iconSize: 30, color: C.TEAL, strokeWidth: 3.4 })
            }
            Column({ space: 4 }) {
              Text(`总进度 ${this.percent()}%`).fontSize(21).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
              Text(`${this.doneCnt}/${this.totalCnt} 节点已完成`).fontSize(12.5).fontColor(C.TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding(16)
          .backgroundColor(C.CARD)
          .borderRadius(16)

          // 树状节点
          Column() {
            ForEach(this.nodes, (n: FlowNode, idx: number) => {
              Row({ space: 0 }) {
                // 左侧轨道
                Column() {
                  if (n.level === 1) {
                    Row()
                      .width(14)
                      .height(2)
                      .backgroundColor(n.done ? C.PRIMARY : '#C8CDD4')
                      .margin({ top: 18 })
                  } else if (idx > 0) {
                    Row()
                      .width(2)
                      .height(18)
                      .backgroundColor('#C8CDD4')
                  }
                  Stack() {
                    if (n.done) {
                      Circle({ width: 22, height: 22 }).fill(C.PRIMARY)
                      SvgIcon({ name: 'check', iconSize: 13, color: '#FFFFFF', strokeWidth: 3 })
                    } else if (n.id === this.currentId) {
                      Circle({ width: 22, height: 22 }).fill(C.CARD).stroke(C.PRIMARY).strokeWidth(2)
                      SvgIcon({ name: 'chevron', iconSize: 12, color: C.PRIMARY, strokeWidth: 2.6 })
                    } else {
                      Circle({ width: 18, height: 18 }).fillOpacity(0).stroke('#C8CDD4').strokeWidth(1.8)
                    }
                  }
                  .width(24)
                  .height(24)
                  if (idx < this.nodes.length - 1) {
                    Row()
                      .width(2)
                      .layoutWeight(1)
                      .backgroundColor(n.done && this.nodes[idx + 1].done ? C.PRIMARY : '#C8CDD4')
                  }
                }
                .width(24)
                .alignItems(HorizontalAlign.Center)

                // 内容
                Text(n.title)
                  .fontSize(n.level === 0 ? 14 : 12.5)
                  .fontWeight(n.id === this.currentId ? FontWeight.Medium : FontWeight.Normal)
                  .fontColor(n.done ? C.TEXT : (n.id === this.currentId ? C.TEXT : C.TEXT_SUB))
                  .margin({ left: 12 })
                Blank()
                if (n.id === this.currentId && !n.done) {
                  Text('进行中')
                    .fontSize(9.5)
                    .fontColor(C.PRIMARY)
                    .border({ width: 1, color: C.PRIMARY })
                    .borderRadius(10)
                    .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                }
              }
              .width('100%')
              .height(n.level === 1 ? 44 : 56)
              .onClick(() => { this.onNodeClick(n); })
            }, (n: FlowNode) => n.id + n.done.toString())
          }
          .width('100%')
          .padding(16)
          .backgroundColor(C.CARD)
          .borderRadius(16)
          .margin({ top: 14 })

          Blank().height(90)
        }
        .width('100%')
        .padding(14)
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)

      // 底部操作
      Row({ space: 12 }) {
        Button('刷新流程')
          .layoutWeight(1).height(46)
          .backgroundColor('#E3E7EC')
          .fontColor(C.TEXT)
          .fontSize(15)
          .onClick(() => { this.refreshFlow(); })
        Button('跳转导航')
          .layoutWeight(1).height(46)
          .backgroundColor(C.PRIMARY)
          .fontColor(Color.White)
          .fontSize(15)
          .onClick(() => { router.pushUrl({ url: 'pages/MapNavPage' }); })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 14 })
      .backgroundColor(C.CARD)
      .border({ width: 0.6, color: C.LINE })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.BG)
  }
}

@Entry
@Component
struct FlowTreePage {
  build() {
    Column() {
      FlowTreeView()
    }
    .width('100%')
    .height('100%')
  }
}
