// 启动页：按登录态分流到 登录页 / 主页
import { router } from '@kit.ArkUI';
import { SCHOOL_NAME } from '../model/AppModels';
import { C, APP_LABEL } from '../common/Theme';

@Entry
@Component
struct Index {
  aboutToAppear(): void {
    setTimeout(() => {
      const logged: boolean = AppStorage.get<boolean>('loggedIn') ?? false;
      if (logged) {
        router.replaceUrl({ url: 'pages/MainPage' });
      } else {
        router.replaceUrl({ url: 'pages/LoginPage' });
      }
    }, 700);
  }

  build() {
    Column() {
      Column() {
        Stack() {
          Circle({ width: 104, height: 104 }).fill(C.PRIMARY_LIGHT)
          Image($r('app.media.feature_map')).width(94).height(94).objectFit(ImageFit.Contain)
        }
        Text(APP_LABEL)
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(C.TEXT)
          .margin({ top: 18 })
        Text(SCHOOL_NAME)
          .fontSize(15)
          .fontColor(C.TEXT_SUB)
          .margin({ top: 8 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      LoadingProgress().width(34).height(34).color(C.PRIMARY)
      Text('正在为您准备报到服务…').fontSize(13).fontColor(C.TEXT_HINT).margin({ top: 12, bottom: 80 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(C.BG)
  }
}
