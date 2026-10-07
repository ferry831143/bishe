// AI 行程管家：行程概览 + 差异化清单入口 + 对话（本地规则引擎，预留 LLM API 接入口）
import { router, promptAction, AlertDialog } from '@kit.ArkUI';
import { ChatMsg, StudentInfo } from '../model/AppModels';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { Store } from '../common/Store';
import { AiEngine } from '../common/AiEngine';

@Component
export struct AiButlerView {
  @StorageLink('studentJson') studentJson: string = '{}';
  @StorageLink('chatJson') @Watch('onChatChange') chatJson: string = '[]';
  @StorageLink('flowDoneJson') flowDoneJson: string = '[]';
  @StorageLink('deepSeekApiKey') deepSeekApiKey: string = '';
  @State msgs: ChatMsg[] = [];
  @State input: string = '';
  @State name: string = '';
  @State sid: string = '';
  @State tripSummary: string = '尚未填写行程信息';
  @State showBack: boolean = true;
  private scroller: Scroller = new Scroller();
  private pending: boolean = false;

  aboutToAppear(): void {
    this.parseAll();
  }

  onChatChange(): void {
    try {
      this.msgs = JSON.parse(this.chatJson) as ChatMsg[];
    } catch (e) {
      this.msgs = [];
    }
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 60);
  }

  private parseAll(): void {
    try {
      const st = JSON.parse(this.studentJson) as StudentInfo;
      this.name = st.name;
      this.sid = st.studentId;
      if (st.trainNo.length > 0 || st.station.length > 0) {
        this.tripSummary = `${st.transport} ${st.trainNo} · ${st.arriveTime} 到达 ${st.station}`;
      }
    } catch (e) {
      this.name = '';
      this.sid = '';
    }
    try {
      this.msgs = JSON.parse(this.chatJson) as ChatMsg[];
    } catch (e) {
      this.msgs = [];
    }
  }

  private currentFlowName(): string {
    let done: string[] = [];
    try {
      done = JSON.parse(this.flowDoneJson) as string[];
    } catch (e) {
      done = [];
    }
    if (done.indexOf('dorm') >= 0) {
      return '宿舍入住';
    }
    if (done.indexOf('campus') >= 0) {
      return '校内报到';
    }
    return '到校打卡 - 接站';
  }

  private async send(text: string): Promise<void> {
    const q: string = text.trim();
    if (q.length === 0 || this.pending) {
      return;
    }
    const next: ChatMsg[] = this.msgs.concat([{ role: 'user', text: q } as ChatMsg]);
    this.pending = true;
    Store.saveChat(next);
    this.input = '';
    let reply: string = '';
    try {
      if (this.deepSeekApiKey.trim().length === 0) {
        reply = '尚未连接 DeepSeek。请在「个人中心 → DeepSeek API 配置」中填写 API Key。';
      } else {
        this.msgs = next.concat([{ role: 'ai', text: '正在思考…' } as ChatMsg]);
        reply = await AiEngine.streamFromLLM(q, Store.student(), this.deepSeekApiKey.trim(), (streamed: string) => {
          this.msgs = next.concat([{ role: 'ai', text: streamed.length > 0 ? streamed : '正在思考…' } as ChatMsg]);
          this.scroller.scrollEdge(Edge.Bottom);
        });
      }
    } catch (e) {
      reply = `DeepSeek 连接失败：${(e as Error).message}。请检查 API Key 与网络。`;
    }
    Store.saveChat(next.concat([{ role: 'ai', text: AiEngine.cleanText(reply) } as ChatMsg]));
    this.pending = false;
  }

  private quick(q: string): void {
    this.send(q);
  }

  @Builder
  bubble(m: ChatMsg, idx: number) {
    Row({ space: 8 }) {
      if (m.role === 'ai') {
        Stack() {
          Circle({ width: 30, height: 30 }).fill(C.NAVY)
          Text('AI').fontSize(11).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        }
      }
      Text(AiEngine.cleanText(m.text))
        .fontSize(13)
        .fontColor(m.role === 'ai' ? C.TEXT : '#FFFFFF')
        .lineHeight(20)
        .constraintSize({ maxWidth: 270 })
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor(m.role === 'ai' ? C.CARD : C.PRIMARY)
        .borderRadius(14)
      if (m.role === 'user') {
        Image($r('app.media.default_student_avatar')).width(32).height(32).borderRadius(16).objectFit(ImageFit.Cover)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    .justifyContent(m.role === 'ai' ? FlexAlign.Start : FlexAlign.End)
  }

  build() {
    Column() {
      // 页头
      Row() {
        if (this.showBack) {
          SvgIcon({ name: 'back', iconSize: 22, color: C.TEXT, strokeWidth: 2 })
            .onClick(() => { router.back(); })
            .margin({ right: 12 })
        }
        Text('AI 行程管家').fontSize(18).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
        Blank()
        Text(`${this.name} | ${this.sid}`).fontSize(12).fontColor(C.TEXT_SUB)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Scroll(this.scroller) {
        Column() {
          Row({ space: 12 }) {
            Image($r('app.media.nav_ai')).width(48).height(48).objectFit(ImageFit.Contain)
            Column({ space: 5 }) {
              Text(this.deepSeekApiKey.length > 0 ? 'DeepSeek 已连接' : 'DeepSeek 尚未配置')
                .fontSize(17).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
              Text(this.tripSummary).fontSize(12).fontColor(C.TEXT_SUB).maxLines(2)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          }
          .width('100%').padding(15).backgroundColor('#EAF7F0').borderRadius(16)

          Row({ space: 10 }) {
            Column({ space: 7 }) {
              Image($r('app.media.feature_packing')).width(42).height(42).objectFit(ImageFit.Contain)
              Text('我的行李清单').fontSize(13).fontWeight(FontWeight.Medium).fontColor(C.TEXT)
              Text('查看与勾选物品').fontSize(10).fontColor(C.TEXT_SUB)
            }.layoutWeight(1).padding(12).backgroundColor(C.CARD).borderRadius(14)
              .onClick(() => { router.pushUrl({ url: 'pages/PackingListPage' }); })
            Column({ space: 7 }) {
              Image($r('app.media.feature_bus')).width(42).height(42).objectFit(ImageFit.Contain)
              Text('接站信息').fontSize(13).fontWeight(FontWeight.Medium).fontColor(C.TEXT)
              Text('公交与接站查询').fontSize(10).fontColor(C.TEXT_SUB).maxLines(1)
            }.layoutWeight(1).padding(12).backgroundColor(C.CARD).borderRadius(14)
              .onClick(() => { router.pushUrl({ url: 'pages/PickupCenterPage' }); })
          }.width('100%').margin({ top: 10 })

          // 聊天区
          Row({ space: 8 }) {
            Image($r('app.media.default_student_avatar')).width(32).height(32).borderRadius(16).objectFit(ImageFit.Cover)
            Column({ space: 6 }) {
              Text(`${this.name}同学，可以直接向 DeepSeek 咨询行程问题。`)
                .fontSize(12.5).fontColor(C.TEXT)
              Text('回答会逐字流式显示').fontSize(10.5).fontColor(C.TEXT_SUB)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 14 })

          Column() {
            ForEach(this.msgs, (m: ChatMsg, idx: number) => {
              this.bubble(m, idx)
            }, (m: ChatMsg, idx: number) => m.role + m.text.slice(0, 12) + idx.toString())
          }
          .width('100%')
          .margin({ top: 10, bottom: 8 })

          // 快捷指令
          Row({ space: 8 }) {
            ForEach(['查清单', '接站在哪', '报到流程', '天气提醒'], (q: string) => {
              Text(q)
                .fontSize(11.5)
                .fontColor(C.PRIMARY)
                .backgroundColor(C.PRIMARY_LIGHT)
                .borderRadius(12)
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .onClick(() => { this.quick(q); })
            }, (q: string) => q)
          }
          .width('100%')
          .margin({ bottom: 10 })
        }
        .width('100%')
        .padding(14)
      }
      .layoutWeight(1)
      .scrollable(ScrollDirection.Vertical)

      // 输入区
      Row({ space: 8 }) {
        TextInput({ placeholder: '请输入信息…', text: this.input })
          .height(40)
          .fontSize(13.5)
          .backgroundColor(C.CARD)
          .borderRadius(20)
          .layoutWeight(1)
          .onChange((v: string) => { this.input = v; })
          .onSubmit(() => { this.send(this.input); })
        Button('发送')
          .height(34)
          .backgroundColor(C.PRIMARY)
          .fontSize(13)
          .padding({ left: 14, right: 14 })
          .onClick(() => { this.send(this.input); })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 10 })
      .backgroundColor(C.BG)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.BG)
  }
}

@Entry
@Component
struct AiButlerPage {
  build() {
    Column() {
      AiButlerView({ showBack: true })
    }
    .width('100%')
    .height('100%')
  }
}
