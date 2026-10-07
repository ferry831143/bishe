// 主框架：底部 4 Tab（首页 / 地图导航 / AI 行程管家 / 个人中心）
import { HomePage } from './HomePage';
import { ProfilePage } from './ProfilePage';
import { MapNavView } from './MapNavPage';
import { AiButlerView } from './AiButlerPage';
import { C } from '../common/Theme';

// 注意：自定义组件成员名不可与 ArkUI 内置属性方法同名（曾因 active/size/tabIndex 踩坑）
@Component
struct TabItem {
  @Prop tabIcon: string = 'home';
  @Prop tabLabel: string = '';
  @Prop isActive: boolean = false;

  private iconResource(): Resource {
    if (this.tabIcon === 'map') return $r('app.media.nav_map');
    if (this.tabIcon === 'robot') return $r('app.media.nav_ai');
    if (this.tabIcon === 'user') return $r('app.media.nav_profile');
    return $r('app.media.nav_home');
  }

  build() {
    Column({ space: 5 }) {
      Image(this.iconResource()).width(34).height(34).objectFit(ImageFit.Contain)
        .opacity(this.isActive ? 1 : 0.52)
      Text(this.tabLabel)
        .fontSize(10.5)
        .fontColor(this.isActive ? C.PRIMARY : '#9AA0A8')
        .fontWeight(this.isActive ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height(72)
    .justifyContent(FlexAlign.Center)
  }
}

@Entry
@Component
struct MainPage {
  @State curTab: number = 0;

  // 自定义 TabBar 必须通过 CustomBuilder 传入（API20 不接受组件实例）
  @Builder
  tabBuilder(icon: string, label: string, target: number) {
    TabItem({ tabIcon: icon, tabLabel: label, isActive: this.curTab === target })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.curTab }) {
      TabContent() {
        HomePage({ goTab: (i: number): void => { this.curTab = i; } })
      }
      .tabBar(this.tabBuilder('home', '首页', 0))

      TabContent() {
        Scroll() {
          MapNavView({ showBack: false })
        }
        .scrollable(ScrollDirection.Vertical)
        .edgeEffect(EdgeEffect.Spring)
      }
      .tabBar(this.tabBuilder('map', '地图导航', 1))

      TabContent() {
        AiButlerView({ showBack: false })
      }
      .tabBar(this.tabBuilder('robot', 'AI 行程管家', 2))

      TabContent() {
        ProfilePage()
      }
      .tabBar(this.tabBuilder('user', '个人中心', 3))
    }
    .scrollable(false)
    .barHeight(76)
    .backgroundColor(C.BG)
    .onChange((i: number) => { this.curTab = i; })
  }
}
