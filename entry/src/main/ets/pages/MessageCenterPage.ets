// 独立消息中心：本机多账号匹配申请与聊天入口。
import { router, promptAction } from '@kit.ArkUI';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { MatchInboxItem, MatchService } from '../common/MatchService';
import { StudentInfo } from '../model/AppModels';

@Entry
@Component
struct MessageCenterPage {
  @StorageLink('studentJson') studentJson: string = '{}';
  @StorageLink('ocrState') ocrState: string = 'none';
  @State student: StudentInfo | null = null;
  @State items: MatchInboxItem[] = [];
  @State loading: boolean = false;
  @State loadText: string = '';

  aboutToAppear(): void {
    try {
      const parsed = JSON.parse(this.studentJson) as StudentInfo;
      this.student = parsed.studentId ? parsed : null;
    } catch (e) {
      this.student = null;
    }
    this.refreshMatches();
  }

  private async refreshMatches(): Promise<void> {
    this.loading = true;
    this.loadText = '正在同步匹配通知…';
    try {
      this.items = await MatchService.inbox();
      this.loadText = this.items.length === 0 ? '暂无新的盲盒申请' : '';
    } catch (e) {
      this.loadText = '消息同步失败，请稍后重试';
    } finally {
      this.loading = false;
    }
  }

  private async decide(item: MatchInboxItem, accept: boolean): Promise<void> {
    try {
      const msg = await MatchService.decide(item.id, accept);
      promptAction.showToast({ message: msg });
      await this.refreshMatches();
    } catch (e) {
      promptAction.showToast({ message: '操作失败，请检查网络后重试' });
    }
  }

  private statusLabel(status: string): string {
    if (status === 'accepted') return '匹配成功';
    if (status === 'rejected') return '已拒绝';
    return '等待确认';
  }

  build() {
    Column() {
      Row() {
        SvgIcon({ name: 'back', iconSize: 24, color: C.TEXT, strokeWidth: 2 })
          .onClick(() => { router.back(); }).margin({ right: 12 })
        Text('消息中心').fontSize(20).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
        Blank()
        SvgIcon({ name: 'bell', iconSize: 22, color: C.PRIMARY, strokeWidth: 1.8 })
      }.width('100%').padding({ left: 16, right: 16, top: 14, bottom: 12 })

      Scroll() {
        Column({ space: 14 }) {
          Text('账号与报到').fontSize(15).fontWeight(FontWeight.Bold).fontColor(C.TEXT).width('100%')
          Column() {
            this.infoRow('user', '账号状态', this.student === null ? '未登录' : `${this.student.name} · ${this.student.studentId}`)
            Divider().strokeWidth(0.6).color(C.LINE).margin({ left: 46 })
            this.infoRow('idcard', '证件预审', this.ocrState === 'passed' ? '已通过' : this.ocrState === 'submitted' ? '审核中' : '未提交')
            Divider().strokeWidth(0.6).color(C.LINE).margin({ left: 46 })
            this.infoRow('train', '登记行程', this.student === null ? '未登记' : `${this.student.trainNo || '未填车次'} · ${this.student.arriveTime || '未填时间'}`)
          }.width('100%').padding({ left: 14, right: 14 }).backgroundColor(C.CARD).borderRadius(16)

          Row() {
            Text('盲盒匹配通知').fontSize(15).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
            Blank()
            Text('刷新').fontSize(13).fontColor(C.PRIMARY).onClick(() => { this.refreshMatches(); })
          }.width('100%').margin({ top: 6 })

          if (this.loading) {
            LoadingProgress().width(36).height(36).color(C.PRIMARY).margin({ top: 18 })
          }

          ForEach(this.items, (item: MatchInboxItem) => {
            Column({ space: 10 }) {
              Row({ space: 10 }) {
                Stack() {
                  Circle({ width: 46, height: 46 }).fill('#E6F3EC')
                  SvgIcon({ name: 'gift', iconSize: 25, color: C.PRIMARY, strokeWidth: 1.8 })
                }
                Column({ space: 3 }) {
                  Text(item.direction === 'incoming' ? '收到盲盒匹配申请' : '已发出盲盒匹配申请')
                    .fontSize(14).fontWeight(FontWeight.Medium).fontColor(C.TEXT)
                  Text(`${item.nickname || '匿名用户'} · ${item.category} · ${this.statusLabel(item.status)}`)
                    .fontSize(12).fontColor(C.TEXT_SUB)
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
              }.width('100%')
              if (item.direction === 'incoming' && item.status === 'pending') {
                Row({ space: 10 }) {
                  Button('拒绝').layoutWeight(1).height(38).backgroundColor('#E9EBEE').fontColor(C.TEXT)
                    .onClick(() => { this.decide(item, false); })
                  Button('同意匹配').layoutWeight(2).height(38).backgroundColor(C.PRIMARY)
                    .onClick(() => { this.decide(item, true); })
                }.width('100%')
              }
              if (item.status === 'accepted') {
                Button('进入聊天').width('100%').height(38).backgroundColor('#E6F3EC').fontColor(C.PRIMARY_DARK)
                  .onClick(() => { router.pushUrl({ url: 'pages/MatchChatPage', params: { matchId: item.id, title: item.nickname } }); })
              }
            }.width('100%').padding(14).backgroundColor(C.CARD).borderRadius(16)
          }, (item: MatchInboxItem) => item.id)

          if (this.items.length === 0 && !this.loading) {
            Column({ space: 10 }) {
              SvgIcon({ name: 'bell', iconSize: 42, color: '#BBC3BF', strokeWidth: 1.6 })
              Text(this.loadText).fontSize(13).fontColor(C.TEXT_SUB).textAlign(TextAlign.Center)
              Text('发起盲盒后，对方登录同一手机上的账号即可处理。')
                .fontSize(12).fontColor('#A0A6AA').textAlign(TextAlign.Center)
            }.width('100%').padding({ top: 30, bottom: 30, left: 20, right: 20 })
              .backgroundColor(C.CARD).borderRadius(16)
          }
        }.width('100%').constraintSize({ minHeight: '100%' }).justifyContent(FlexAlign.Start)
          .padding({ left: 14, right: 14, top: 8, bottom: 24 })
      }.layoutWeight(1).scrollable(ScrollDirection.Vertical)
    }.width('100%').height('100%').backgroundColor(C.BG)
  }

  @Builder
  infoRow(icon: string, title: string, value: string) {
    Row({ space: 12 }) {
      SvgIcon({ name: icon, iconSize: 25, color: C.PRIMARY, strokeWidth: 1.8 })
      Column({ space: 3 }) {
        Text(title).fontSize(14).fontWeight(FontWeight.Medium).fontColor(C.TEXT)
        Text(value).fontSize(12).fontColor(C.TEXT_SUB).maxLines(2)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.width('100%').padding({ top: 13, bottom: 13 })
  }
}
