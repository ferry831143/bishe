// 个人中心：信息管理 / 行程绑定 / 证件管理 / 消息 / 清单 / 设置 / 隐私 / 退出登录
import { router, promptAction, AlertDialog } from '@kit.ArkUI';
import { StudentInfo } from '../model/AppModels';
import { C } from '../common/Theme';
import { SvgIcon } from '../common/Icons';
import { Store } from '../common/Store';
import { StudentAvatar } from '../common/Visuals';

@Component
export struct ProfileRow {
  rowIcon: string = 'user';
  rowLabel: string = '';
  rowTag: string = '';
  tagColor: string = '#9AA0A8';

  private iconResource(): Resource {
    if (this.rowIcon === 'checkcircle') return $r('app.media.profile_journey');
    if (this.rowIcon === 'idcard') return $r('app.media.profile_document');
    if (this.rowIcon === 'chat') return $r('app.media.profile_message');
    if (this.rowIcon === 'clipboard') return $r('app.media.profile_checklist');
    if (this.rowIcon === 'gear') return $r('app.media.profile_settings');
    if (this.rowIcon === 'shield') return $r('app.media.profile_privacy');
    if (this.rowIcon === 'robot') return $r('app.media.profile_deepseek');
    return $r('app.media.profile_info');
  }

  build() {
    Row({ space: 12 }) {
      Image(this.iconResource()).width(34).height(34).objectFit(ImageFit.Contain)
      Text(this.rowLabel).fontSize(14).fontColor(C.TEXT)
      Blank()
      if (this.rowTag.length > 0) {
        Text(this.rowTag).fontSize(11).fontColor(this.tagColor)
      }
      SvgIcon({ name: 'chevron', iconSize: 14, color: '#C0C5CC', strokeWidth: 2 })
    }
    .width('100%')
    .height(58)
  }
}

@Component
export struct ProfilePage {
  @StorageLink('studentJson') @Watch('onStChange') studentJson: string = '{}';
  @StorageLink('ocrState') ocrState: string = 'none';
  @StorageLink('flowDoneJson') @Watch('onStChange') flowDoneJson: string = '[]';
  @State st: StudentInfo | null = null;
  @State remindOn: boolean = false;
  @State flowNode: string = '到校报到';
  @StorageLink('deepSeekApiKey') deepSeekApiKey: string = '';
  @State deepSeekInput: string = '';
  @State showDeepSeek: boolean = false;

  aboutToAppear(): void {
    this.parse();
    this.deepSeekInput = this.deepSeekApiKey;
  }

  onStChange(): void {
    this.parse();
  }

  private parse(): void {
    try {
      this.st = JSON.parse(this.studentJson) as StudentInfo;
    } catch (e) {
      this.st = null;
    }
    // 当前节点从持久化流程动态推导（不写死）
    let done: string[] = [];
    try {
      done = JSON.parse(this.flowDoneJson) as string[];
    } catch (e) {
      done = [];
    }
    const has = (id: string): boolean => done.indexOf(id) >= 0;
    if (has('dorm')) {
      this.flowNode = '宿舍入住（已完结）';
    } else if (has('materials')) {
      this.flowNode = '宿舍入住';
    } else if (has('campus')) {
      this.flowNode = '领取材料';
    } else if (has('arriveCheck')) {
      this.flowNode = '校内报到';
    } else if (has('bind')) {
      this.flowNode = '到校报到';
    } else {
      this.flowNode = '行程准备';
    }
  }

  private infoDialog(): void {
    if (this.st === null) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '基本信息',
      message: `姓名：${this.st.name}\n学号：${this.st.studentId}\n专业：${this.st.major}\n生源地：${this.st.hometown}\n宿舍：${this.st.dorm}\n出行方式：${this.st.transport}（${this.st.trainNo}）\n到达：${this.st.arriveTime} ${this.st.station}`,
      confirm: { value: '去修改', action: () => { router.pushUrl({ url: 'pages/EditProfilePage' }); } }
    });
  }

  private bindDialog(): void {
    if (this.st === null) {
      return;
    }
    this.getUIContext().showAlertDialog({
      title: '已登记的行程信息',
      message: `车次/航班：${this.st.trainNo || '未填写'}\n到达时间：${this.st.arriveTime || '未填写'}\n到达站点：${this.st.station || '未填写'}\n\n此处只显示你注册或修改时填写的数据，不生成接站车辆。`,
      confirm: { value: '知道了', action: () => {} }
    });
  }

  private settingDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '系统设置',
      message: `· 行前提醒推送：${this.remindOn ? '已开启' : '未开启'}\n· 深色模式：跟随系统\n· 字体大小：标准\n· 关于：树人智行 v1.0.0（新生报到版）`,
      confirm: {
        value: this.remindOn ? '关闭提醒' : '开启行前提醒',
        action: () => {
          this.remindOn = !this.remindOn;
          promptAction.showToast({ message: this.remindOn ? '行前提醒已开启（正式版接入推送服务）' : '行前提醒已关闭' });
        }
      }
    });
  }

  private privacyDialog(): void {
    this.getUIContext().showAlertDialog({
      title: '隐私保护',
      message: '· 盲盒只会匹配本机已注册的其他账号\n· 对方在消息中心同意后才算匹配成功\n· 身份证图片仅用于本机 OCR 预审，证件号码会脱敏展示',
      confirm: { value: '知道了', action: () => {} }
    });
  }

  private logout(): void {
    this.getUIContext().showAlertDialog({
      title: '退出登录',
      message: '确定退出当前账号吗？本地清单与流程进度将保留。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '退出',
        fontColor: C.RED,
        action: () => {
          Store.saveBool('loggedIn', false);
          router.replaceUrl({ url: 'pages/LoginPage' });
        }
      }
    });
  }

  private ocrTag(): string {
    if (this.ocrState === 'passed') {
      return '审核通过';
    }
    if (this.ocrState === 'submitted') {
      return '审核中';
    }
    return '未提交';
  }

  private ocrTagColor(): string {
    if (this.ocrState === 'passed') {
      return C.PRIMARY;
    }
    if (this.ocrState === 'submitted') {
      return '#F0B24A';
    }
    return '#9AA0A8';
  }

  build() {
    Scroll() {
      Column() {
        Text('个人中心')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.TEXT)
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 10 })

        // 用户卡
        Row({ space: 14 }) {
          StudentAvatar({ name: this.st === null ? '新' : this.st.name, avatarSize: 68 })
          Column({ space: 3 }) {
            if (this.st !== null) {
              Text(this.st.name).fontSize(18).fontWeight(FontWeight.Bold).fontColor(C.TEXT)
              Text(`学号：${this.st.studentId}`).fontSize(12).fontColor(C.TEXT_SUB)
              Text(`专业：${this.st.major}`).fontSize(12).fontColor(C.TEXT_SUB)
              Text(`当前节点：${this.flowNode}`).fontSize(12).fontColor(C.TEXT_SUB)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(C.CARD)
        .borderRadius(16)

        // 管理列表
        Column() {
          ProfileRow({
            rowIcon: 'user', rowLabel: '基本信息管理'
          }).onClick(() => { this.infoDialog(); })
          Divider().strokeWidth(0.6).color(C.LINE).margin({ left: 34 })
          ProfileRow({
            rowIcon: 'checkcircle', rowLabel: '行程信息绑定', rowTag: this.st !== null && this.st.trainNo.length > 0 ? '已绑定' : '未绑定', tagColor: C.PRIMARY
          }).onClick(() => { this.bindDialog(); })
          Divider().strokeWidth(0.6).color(C.LINE).margin({ left: 34 })
          ProfileRow({
            rowIcon: 'idcard', rowLabel: '证件管理', rowTag: this.ocrTag(), tagColor: this.ocrTagColor()
          }).onClick(() => { router.pushUrl({ url: 'pages/OcrPrecheckPage' }); })
          Divider().strokeWidth(0.6).color(C.LINE).margin({ left: 34 })

          ProfileRow({
            rowIcon: 'chat', rowLabel: '消息中心'
          }).onClick(() => { router.pushUrl({ url: 'pages/MessageCenterPage' }); })
          Divider().strokeWidth(0.6).color(C.LINE).margin({ left: 34 })
          ProfileRow({
            rowIcon: 'clipboard', rowLabel: '我的清单'
          }).onClick(() => { router.pushUrl({ url: 'pages/PackingListPage' }); })
          Divider().strokeWidth(0.6).color(C.LINE).margin({ left: 34 })

          ProfileRow({
            rowIcon: 'gear', rowLabel: '系统设置'
          }).onClick(() => { this.settingDialog(); })
          Divider().strokeWidth(0.6).color(C.LINE).margin({ left: 34 })
          ProfileRow({
            rowIcon: 'robot', rowLabel: 'DeepSeek API 配置',
            rowTag: this.deepSeekApiKey.length > 0 ? '已连接' : '未配置', tagColor: C.PRIMARY
          }).onClick(() => {
            this.deepSeekInput = this.deepSeekApiKey;
            this.showDeepSeek = !this.showDeepSeek;
          })
          Divider().strokeWidth(0.6).color(C.LINE).margin({ left: 34 })
          ProfileRow({
            rowIcon: 'shield', rowLabel: '隐私保护'
          }).onClick(() => { this.privacyDialog(); })
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
        .backgroundColor(C.CARD)
        .borderRadius(16)
        .margin({ top: 14 })

        if (this.showDeepSeek) {
          Column({ space: 12 }) {
            Text('DeepSeek API Key').fontSize(16).fontWeight(FontWeight.Bold).fontColor(C.TEXT).width('100%')
            Text('Key 仅保存在本机，用于 AI 行程管家直连 DeepSeek。')
              .fontSize(12).fontColor(C.TEXT_SUB).width('100%')
            TextInput({ text: this.deepSeekInput, placeholder: '请输入 sk- 开头的 API Key' })
              .type(InputType.Password)
              .height(46)
              .backgroundColor('#F2F4F6')
              .borderRadius(12)
              .onChange((value: string) => { this.deepSeekInput = value; })
            Row({ space: 10 }) {
              Button('清除').layoutWeight(1).height(42).backgroundColor('#E9EBEE').fontColor(C.TEXT)
                .onClick(() => {
                  this.deepSeekInput = '';
                  Store.saveStr(Store.K_DEEPSEEK, '');
                  promptAction.showToast({ message: 'DeepSeek Key 已清除' });
                })
              Button('保存并连接').layoutWeight(2).height(42).backgroundColor(C.PRIMARY)
                .onClick(() => {
                  const key = this.deepSeekInput.trim();
                  if (key.length < 10) {
                    promptAction.showToast({ message: '请输入有效的 DeepSeek API Key' });
                    return;
                  }
                  Store.saveStr(Store.K_DEEPSEEK, key);
                  promptAction.showToast({ message: '已保存，AI 管家将使用 DeepSeek' });
                })
            }.width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(16)
          .backgroundColor(C.CARD)
          .borderRadius(16)
          .margin({ top: 12 })
        }

        // 原子化卡片管理
        Column({ space: 10 }) {
          Text('我的原子化卡片管理').fontSize(14).fontWeight(FontWeight.Medium).fontColor(C.TEXT)
            .width('100%')
          Text('按功能挑选一个原子卡片管理的桌面卡片')
            .fontSize(10.5).fontColor(C.TEXT_SUB).width('100%')
          Row({ space: 8 }) {
            this.miniCard('清单', '#4E9E5F')
            this.miniCard('行程', '#1E3A5F')
            this.miniCard('证件', '#5B8FD9')
            this.miniCard('校园卡', '#F08C3C')
          }
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(14)
        .backgroundColor(C.CARD)
        .borderRadius(16)
        .margin({ top: 14 })

        // 退出登录
        Button('退出登录')
          .width('100%')
          .height(46)
          .backgroundColor('#E9EBEE')
          .fontColor(C.TEXT)
          .fontSize(15)
          .margin({ top: 16, bottom: 24 })
          .onClick(() => { this.logout(); })
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

  @Builder
  miniCard(label: string, color: string) {
    Column({ space: 4 }) {
      SvgIcon({ name: label === '清单' ? 'suitcase' : label === '行程' ? 'bus' : label === '证件' ? 'idcard' : 'creditcard', iconSize: 16, color: '#FFFFFF', strokeWidth: 1.9 })
      Text(label).fontSize(9).fontColor('#FFFFFF')
    }
    .layoutWeight(1)
    .height(52)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(color)
    .borderRadius(10)
  }
}
