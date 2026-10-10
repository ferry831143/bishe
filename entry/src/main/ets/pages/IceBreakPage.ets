// 社交破冰：本机多账号真人双向确认匹配。
import { router, promptAction } from '@kit.ArkUI';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { MatchService } from '../common/MatchService';

@Entry
@Component
struct IceBreakPage {
  @State tagSel: string = '同乡';
  @State submitting: boolean = false;
  @State statusText: string = '';

  private tagColor(t: string): string {
    if (t === '同乡') return '#F08C3C';
    if (t === '同专业') return '#5B8FD9';
    return '#4E9E5F';
  }

  private async submitMatch(): Promise<void> {
    if (this.submitting) return;
    this.submitting = true;
    this.statusText = '正在从已注册用户中随机匹配…';
    try {
      this.statusText = await MatchService.createRequest(this.tagSel);
    } catch (e) {
      this.statusText = (e as Error).message;
    } finally {
      this.submitting = false;
    }
  }

  build() {
    Column() {
      Row() {
        SvgIcon({ name: 'back', iconSize: 24, color: C.TEXT, strokeWidth: 2 })
          .onClick(() => { router.back(); }).margin({ right: 12 })
        Text('社交破冰 · 盲盒匹配').fontSize(19).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
        Blank()
        SvgIcon({ name: 'shield', iconSize: 21, color: C.TEXT_SUB, strokeWidth: 1.8 })
      }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 10 })

      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 10 }) {
            Stack() {
              Circle({ width: 82, height: 82 }).fill('#E7F6EE')
              SvgIcon({ name: 'gift', iconSize: 44, color: C.PRIMARY, strokeWidth: 1.8 })
            }
            Text('真人双向确认').fontSize(18).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
            Text(`已有 ${MatchService.accountCount()} 位用户参与匹配`)
              .fontSize(13).fontColor(C.TEXT_SUB)
          }.width('100%').padding({ left: 18, right: 18, top: 24, bottom: 22 })
            .backgroundColor(C.CARD).borderRadius(18)

          Text('选择匹配条件').fontSize(15).fontWeight(FontWeight.Bold).fontColor(C.TEXT).width('100%')
          Row({ space: 9 }) {
            ForEach(['同乡', '同专业', '同宿舍'], (t: string) => {
              Row({ space: 6 }) {
                Circle({ width: 8, height: 8 }).fill(this.tagSel === t ? '#FFFFFF' : this.tagColor(t))
                Text(t).fontSize(14).fontColor(this.tagSel === t ? '#FFFFFF' : C.TEXT)
              }.layoutWeight(1).height(42).justifyContent(FlexAlign.Center)
                .backgroundColor(this.tagSel === t ? this.tagColor(t) : C.CARD).borderRadius(21)
                .onClick(() => { this.tagSel = t; this.statusText = ''; })
            }, (t: string) => t)
          }.width('100%')

          if (this.statusText.length > 0) {
            Text(this.statusText).fontSize(13).fontColor(C.TEXT).lineHeight(20).width('100%')
              .padding(14).backgroundColor('#EEF7F2').borderRadius(12)
          }

          Button(this.submitting ? '正在提交…' : '发起盲盒匹配')
            .width('100%').height(48).fontSize(16)
            .backgroundColor(C.PRIMARY)
            .onClick(() => { this.submitMatch(); })
          Button('查看匹配通知').width('100%').height(46).fontSize(15)
            .backgroundColor('#E6F3EC').fontColor(C.PRIMARY_DARK)
            .onClick(() => { router.pushUrl({ url: 'pages/MessageCenterPage' }); })
        }.width('100%').padding({ left: 14, right: 14, top: 8, bottom: 24 })
      }.layoutWeight(1).scrollable(ScrollDirection.Vertical)
    }.width('100%').height('100%').backgroundColor(C.BG)
  }
}
