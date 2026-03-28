import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { TokenResponse, LoginRequest, RegisterRequest, CaptchaResponse } from '../model/DataModels';

@Component
struct PwdRuleItem {
  @Prop label: string = '';
  @Prop passed: boolean = false;

  build() {
    Row() {
      Text(this.passed ? '\u2713' : '\u2717')
        .fontSize(13)
        .fontColor(this.passed ? AppColors.PRIMARY : AppColors.WARN)
        .margin({ right: 6 })
      Text(this.label)
        .fontSize(12)
        .fontColor(this.passed ? AppColors.PRIMARY : AppColors.TEXT_HINT)
    }
    .margin({ top: 3 })
  }
}

@Entry
@Component
struct Login {
  @State username: string = '';
  @State password: string = '';
  @State confirmPwd: string = '';
  @State captchaInput: string = '';
  @State captchaId: string = '';
  @State captchaText: string = '----';
  @State isLogin: boolean = true;
  @State loading: boolean = false;
  @State errorMsg: string = '';

  aboutToAppear(): void {
    this.loadCaptcha();
  }

  async loadCaptcha(): Promise<void> {
    try {
      const res = await ApiService.get<CaptchaResponse>(ApiConstants.AUTH_CAPTCHA);
      this.captchaId = res.captcha_id;
      this.captchaText = res.captcha_text;
    } catch (e) {
      // 离线时生成本地模拟验证码
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      let code = '';
      for (let i = 0; i < 4; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      this.captchaText = code;
      this.captchaId = 'local';
    }
  }

  hasMinLen(): boolean {
    return this.password.length >= 8;
  }

  hasUpper(): boolean {
    return /[A-Z]/.test(this.password);
  }

  hasLower(): boolean {
    return /[a-z]/.test(this.password);
  }

  hasDigit(): boolean {
    return /[0-9]/.test(this.password);
  }

  hasSymbol(): boolean {
    return /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?~`]/.test(this.password);
  }

  isPasswordValid(): boolean {
    return this.hasMinLen();
  }

  async handleSubmit(): Promise<void> {
    if (!this.username || !this.password) {
      this.errorMsg = '请输入用户名和密码';
      return;
    }

    if (!this.isLogin) {
      // 注册模式额外校验
      if (!this.isPasswordValid()) {
        this.errorMsg = '密码不满足强度要求';
        return;
      }
      if (this.password !== this.confirmPwd) {
        this.errorMsg = '两次输入的密码不一致';
        return;
      }
      if (!this.captchaInput) {
        this.errorMsg = '请输入验证码';
        return;
      }
      if (this.captchaInput.toUpperCase() !== this.captchaText.toUpperCase()) {
        this.errorMsg = '验证码错误';
        this.loadCaptcha();
        this.captchaInput = '';
        return;
      }
    }

    this.loading = true;
    this.errorMsg = '';
    try {
      if (this.isLogin) {
        const body: LoginRequest = { username: this.username, password: this.password };
        const res = await ApiService.post<TokenResponse>(ApiConstants.AUTH_LOGIN, body);
        ApiService.saveToken(res.access_token, res.username, res.role);
      } else {
        const body: RegisterRequest = {
          username: this.username,
          password: this.password,
          captcha_id: this.captchaId,
          captcha_code: this.captchaInput
        };
        const res = await ApiService.post<TokenResponse>(ApiConstants.AUTH_REGISTER, body);
        ApiService.saveToken(res.access_token, res.username, res.role);
      }
      this.getUIContext().getRouter().pushUrl({ url: 'pages/Index' });
    } catch (e) {
      if (e instanceof Error) {
        this.errorMsg = e.message;
      } else {
        this.errorMsg = this.isLogin ? '登录失败，请稍后重试' : '注册失败，请稍后重试';
      }
      this.loadCaptcha();
      this.captchaInput = '';
    } finally {
      this.loading = false;
    }
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          // ===== 顶部 Logo =====
          Column() {
            SymbolGlyph($r('sys.symbol.leaf'))
              .fontSize(56)
              .fontColor([AppColors.PRIMARY])
              .margin({ top: 60 })
            Text('智慧农业控制系统')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppColors.PRIMARY_DARK)
              .margin({ top: 10 })
            Text('基于OpenHarmony的智慧农业解决方案')
              .fontSize(13)
              .fontColor(AppColors.TEXT_SECONDARY)
              .margin({ top: 6 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // ===== 登录/注册切换 =====
          Row() {
            Text('登录')
              .fontSize(18)
              .fontWeight(this.isLogin ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(this.isLogin ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
              .onClick(() => { 
                if (!this.isLogin) {
                  this.isLogin = true; 
                  this.errorMsg = ''; 
                  this.captchaInput = '';
                }
              })
              .padding({ left: 16, right: 16, bottom: 8 })
              .border({ width: { bottom: this.isLogin ? 2 : 0 }, color: AppColors.PRIMARY })
            Text('注册')
              .fontSize(18)
              .fontWeight(!this.isLogin ? FontWeight.Bold : FontWeight.Normal)
              .fontColor(!this.isLogin ? AppColors.PRIMARY : AppColors.TEXT_SECONDARY)
              .onClick(() => {
                this.isLogin = false;
                this.errorMsg = '';
                this.loadCaptcha();
              })
              .padding({ left: 16, right: 16, bottom: 8 })
              .border({ width: { bottom: !this.isLogin ? 2 : 0 }, color: AppColors.PRIMARY })
          }
          .margin({ top: 36, bottom: 24 })

          // ===== 用户名 =====
          TextInput({ placeholder: '请输入用户名', text: this.username })
            .type(InputType.Normal)
            .width('85%')
            .height(48)
            .backgroundColor(AppColors.CARD_BG)
            .backdropBlur(20)
            .borderRadius(24)
            .padding({ left: 20, right: 20 })
            .margin({ bottom: 14 })
            .shadow({ radius: 8, color: '#05000000', offsetX: 0, offsetY: 2 })
            .onChange((value: string) => { this.username = value; })

          // ===== 密码 =====
          TextInput({ placeholder: '请输入密码', text: this.password })
            .type(InputType.Password)
            .width('85%')
            .height(48)
            .backgroundColor(AppColors.CARD_BG)
            .backdropBlur(20)
            .borderRadius(24)
            .padding({ left: 20, right: 20 })
            .margin({ bottom: this.isLogin ? 8 : 6 })
            .shadow({ radius: 8, color: '#05000000', offsetX: 0, offsetY: 2 })
            .onChange((value: string) => { this.password = value; })

          // ===== 注册模式：密码强度提示 =====
          if (!this.isLogin) {
            Column() {
              PwdRuleItem({ label: '至少8位字符', passed: this.password.length >= 8 })
              PwdRuleItem({ label: '包含大写字母 (A-Z)', passed: /[A-Z]/.test(this.password) })
              PwdRuleItem({ label: '包含小写字母 (a-z)', passed: /[a-z]/.test(this.password) })
              PwdRuleItem({ label: '包含数字 (0-9)', passed: /[0-9]/.test(this.password) })
              PwdRuleItem({ label: '包含特殊符号 (!@#$...)', passed: /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?~`]/.test(this.password) })
            }
            .width('85%')
            .padding({ left: 8, top: 4, bottom: 10 })
            .alignItems(HorizontalAlign.Start)

            // ===== 确认密码 =====
            TextInput({ placeholder: '请再次输入密码', text: this.confirmPwd })
              .type(InputType.Password)
              .width('85%')
              .height(48)
              .backgroundColor('#F0F0F0')
              .borderRadius(24)
              .padding({ left: 20, right: 20 })
              .margin({ bottom: 14 })
              .onChange((value: string) => { this.confirmPwd = value; })

            // ===== 验证码 =====
            Row() {
              TextInput({ placeholder: '验证码', text: this.captchaInput })
                .type(InputType.Normal)
                .width(140)
                .height(48)
                .backgroundColor('#F0F0F0')
                .borderRadius(24)
                .padding({ left: 20, right: 20 })
                .onChange((value: string) => { this.captchaInput = value; })

              // 验证码显示框
              Row() {
                Text(this.captchaText)
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                  .letterSpacing(6)
              }
              .width(120)
              .height(48)
              .backgroundColor('#5C6BC0')
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
              .margin({ left: 12 })
              .onClick(() => { this.loadCaptcha(); })

              SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                .fontSize(20)
                .fontColor([AppColors.TEXT_SECONDARY])
                .margin({ left: 8 })
                .onClick(() => { this.loadCaptcha(); })
            }
            .width('85%')
            .margin({ bottom: 8 })
          }

          // ===== 错误提示 =====
          if (this.errorMsg) {
            Text(this.errorMsg)
              .fontSize(13)
              .fontColor(AppColors.WARN)
              .margin({ top: 6 })
          }

          // ===== 提交按钮 =====
          Button(this.loading ? '请稍候...' : (this.isLogin ? '登 录' : '注 册'))
            .width('85%')
            .height(48)
            .borderRadius(24)
            .linearGradient({ direction: GradientDirection.Right, colors: [['#00b09b', 0.0], ['#96c93d', 1.0]] })
            .fontColor('#FFFFFF')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .margin({ top: 20 })
            .enabled(!this.loading)
            .shadow({ radius: 10, color: '#2000b09b', offsetX: 0, offsetY: 4 })
            .onClick(() => { this.handleSubmit(); })

          // ===== 跳过登录 =====
          Text('跳过登录 >')
            .fontSize(13)
            .fontColor(AppColors.TEXT_HINT)
            .margin({ top: 20, bottom: 30 })
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/Index' });
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  pwdRule(label: string, passed: boolean) {
    Row() {
      // 这里的 passed 参数在 ArkTS 某些版本中可能不会随底层数据自动刷新
      // 通过在 label 和 passed 判断中强制引用全局 this.password 的计算结果来触发 UI 响应
      Text(passed ? '\u2713' : '\u2717')
        .fontSize(13)
        .fontColor(passed ? AppColors.PRIMARY : AppColors.WARN)
        .margin({ right: 6 })
      Text(label)
        .fontSize(12)
        .fontColor(passed ? AppColors.PRIMARY : AppColors.TEXT_HINT)
    }
    .margin({ top: 3 })
  }
}
