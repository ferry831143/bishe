// 原型化的通用视觉组件：大尺寸彩色入口图标与学生头像。
@Component
export struct StudentAvatar {
  @Prop name: string = '新';
  @Prop avatarSize: number = 52;

  build() {
    Image($r('app.media.default_student_avatar'))
      .borderRadius(this.avatarSize / 2)
      .objectFit(ImageFit.Cover)
      .border({ width: 2, color: '#D8EAF4' })
    .width(this.avatarSize)
    .height(this.avatarSize)
  }
}

@Component
export struct FeatureIcon {
  @Prop iconRes: Resource = $r('app.media.feature_map');
  @Prop iconBox: number = 64;

  build() {
    Image(this.iconRes)
    .width(this.iconBox)
    .height(this.iconBox)
    .objectFit(ImageFit.Contain)
  }
}
