import { router, promptAction } from '@kit.ArkUI';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { DirectMessage, MatchService } from '../common/MatchService';
import { Store } from '../common/Store';

interface ChatParams {
  matchId: string;
  title: string;
}

@Entry
@Component
struct MatchChatPage {
  @State matchId: string = '';
  @State title: string = '匹配同学';
  @State input: string = '';
  @State messages: DirectMessage[] = [];
  private myId: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const params = router.getParams() as ChatParams;
    this.matchId = params.matchId;
    this.title = params.title || '匹配同学';
    this.myId = Store.student().studentId;
    this.refresh();
  }

  private refresh(): void {
    this.messages = MatchService.messages(this.matchId);
    setTimeout(() => { this.scroller.scrollEdge(Edge.Bottom); }, 40);
  }

  private send(): void {
    const text = this.input.trim();
    if (text.length === 0) return;
    try {
      MatchService.sendMessage(this.matchId, text);
      this.input = '';
      this.refresh();
    } catch (e) {
      promptAction.showToast({ message: '消息发送失败' });
    }
  }

  build() {
    Column() {
      Row() {
        SvgIcon({ name: 'back', iconSize: 24, color: C.TEXT, strokeWidth: 2 })
          .onClick(() => { router.back(); }).margin({ right: 12 })
        Column({ space: 2 }) {
          Text(this.title).fontSize(18).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
          Text('已匹配').fontSize(11).fontColor(C.PRIMARY)
        }.alignItems(HorizontalAlign.Start)
        Blank()
      }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 12 }).backgroundColor(C.CARD)

      Scroll(this.scroller) {
        Column({ space: 12 }) {
          if (this.messages.length === 0) {
            Text('匹配成功，打个招呼吧').fontSize(12).fontColor(C.TEXT_SUB).margin({ top: 24 })
          }
          ForEach(this.messages, (m: DirectMessage) => {
            Row() {
              if (m.fromId === this.myId) Blank()
              Column({ space: 4 }) {
                Text(m.text).fontSize(14).fontColor(m.fromId === this.myId ? '#FFFFFF' : C.TEXT)
                  .lineHeight(20).padding({ left: 13, right: 13, top: 9, bottom: 9 })
                  .backgroundColor(m.fromId === this.myId ? C.PRIMARY : C.CARD).borderRadius(15)
                Text(m.createdAt).fontSize(9).fontColor('#A0A6AA')
              }.alignItems(m.fromId === this.myId ? HorizontalAlign.End : HorizontalAlign.Start)
              if (m.fromId !== this.myId) Blank()
            }.width('100%')
          }, (m: DirectMessage) => m.id)
        }.width('100%').padding(14)
      }.layoutWeight(1).scrollable(ScrollDirection.Vertical)

      Row({ space: 10 }) {
        TextInput({ text: this.input, placeholder: '输入消息' }).layoutWeight(1).height(44)
          .backgroundColor('#F1F3F5').borderRadius(22)
          .onChange((v: string) => { this.input = v; })
        Button('发送').height(42).backgroundColor(C.PRIMARY).onClick(() => { this.send(); })
      }.width('100%').padding({ left: 14, right: 14, top: 10, bottom: 16 }).backgroundColor(C.CARD)
    }.width('100%').height('100%').backgroundColor(C.BG)
  }
}
