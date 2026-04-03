import { router } from '@kit.ArkUI';
import { ApiService } from '../common/ApiService';
import { ApiConstants, AppColors } from '../common/Constants';
import { TokenResponse, LoginRequest, RegisterRequest, CaptchaResponse } from '../model/DataModels';

@Entry
@Component
struct Login {
  @State username: string = '';
  @State password: string = '';
  @State confirmPwd: string = '';
  @State captchaInput: string = '';
  @State captchaId: string = '';
  @State captchaText: string = '----';
  @State captchaImage: string = '';
  @State isLogin: boolean = true;
  @State loading: boolean = false;
  @State errorMsg: string = '';

  aboutToAppear(): void {
    this.loadCaptcha();
  }

  async loadCaptcha(): Promise<void> {
    try {
      const res: CaptchaResponse = await ApiService.get<CaptchaResponse>(ApiConstants.AUTH_CAPTCHA);
      this.captchaId = res.captcha_id;
      this.captchaImage = res.captcha_image;
      this.captchaText = res.captcha_text || '----';
    } catch (_e) {
      const chars: string = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      let code: string = '';
      for (let i: number = 0; i < 4; i++) {
        code += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      this.captchaText = code;
      this.captchaImage = '';
      this.captchaId = 'local';
    }
  }

  hasMinLen(): boolean { return this.password.length >= 8; }
  hasUpper(): boolean { return /[A-Z]/.test(this.password); }
  hasLower(): boolean { return /[a-z]/.test(this.password); }
  hasDigit(): boolean { return /[0-9]/.test(this.password); }
  hasSymbol(): boolean { return /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?~`]/.test(this.password); }

  isPasswordValid(): boolean {
    return this.hasMinLen() && this.hasUpper() && this.hasLower() && this.hasDigit() && this.hasSymbol();
  }

  async handleSubmit(): Promise<void> {
    if (!this.username || !this.password) {
      this.errorMsg = '请输入用户名和密码';
      return;
    }

    if (!this.isLogin) {
      if (!this.isPasswordValid()) {
        this.errorMsg = '密码强度不足';
        return;
      }
      if (this.password !== this.confirmPwd) {
        this.errorMsg = '两次密码不一致';
        return;
      }
      if (!this.captchaInput) {
        this.errorMsg = '请输入验证码';
        return;
      }
    }

    this.loading = true;
    this.errorMsg = '';

    try {
      if (this.isLogin) {
        const body: LoginRequest = { username: this.username, password: this.password };
        const res: TokenResponse = await ApiService.post<TokenResponse>(ApiConstants.AUTH_LOGIN, body);
        ApiService.saveToken(res.access_token, res.username, res.role);
      } else {
        const body: RegisterRequest = {
          username: this.username,
          password: this.password,
          captcha_id: this.captchaId,
          captcha_code: this.captchaInput,
        };
        const res: TokenResponse = await ApiService.post<TokenResponse>(ApiConstants.AUTH_REGISTER, body);
        ApiService.saveToken(res.access_token, res.username, res.role);
      }
      router.pushUrl({ url: 'pages/Index' });
    } catch (_e) {
      this.errorMsg = this.isLogin ? '登录失败' : '注册失败';
      if (!this.isLogin) {
        this.loadCaptcha();
        this.captchaInput = '';
      }
    } finally {
      this.loading = false;
    }
  }

  build(): void {
    Column() {
      Column() {
        Text('智慧农业平台')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF');
        Text('分布式温室智能运维')
          .fontSize(12)
          .fontColor('#D5EBDD')
          .margin({ top: 4 });
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 36, bottom: 28 })
      .backgroundColor(AppColors.PRIMARY_DARK)
      .borderRadius({ bottomLeft: 26, bottomRight: 26 })
      .alignItems(HorizontalAlign.Start);

      Column() {
        Row() {
          this.tabButton('登录', this.isLogin, (): void => {
            this.isLogin = true;
            this.errorMsg = '';
          });
          this.tabButton('注册', !this.isLogin, (): void => {
            this.isLogin = false;
            this.errorMsg = '';
            this.loadCaptcha();
          });
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ bottom: 14 });

        this.fieldInput('用户名', this.username, false, (value: string): void => { this.username = value; });
        this.fieldInput('密码', this.password, true, (value: string): void => { this.password = value; });

        if (!this.isLogin) {
          this.fieldInput('确认密码', this.confirmPwd, true, (value: string): void => { this.confirmPwd = value; });

          Row() {
            TextInput({ placeholder: '验证码', text: this.captchaInput })
              .type(InputType.Normal)
              .height(46)
              .layoutWeight(1)
              .backgroundColor('#F3F7F4')
              .borderRadius(12)
              .padding({ left: 14, right: 14 })
              .onChange((value: string): void => {
                this.captchaInput = value;
              });

            Row() {
              if (this.captchaImage) {
                Image(this.captchaImage)
                  .width(112)
                  .height(46)
                  .borderRadius(10);
              } else {
                Text(this.captchaText)
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FFFFFF')
                  .letterSpacing(3);
              }
            }
            .width(112)
            .height(46)
            .backgroundColor('#4A739E')
            .borderRadius(10)
            .justifyContent(FlexAlign.Center)
            .margin({ left: 10 })
            .onClick((): void => {
              this.loadCaptcha();
            });
          }
          .width('100%')
          .margin({ top: 10 });

          Column() {
            this.pwdRule('至少 8 位', this.hasMinLen());
            this.pwdRule('包含大写字母', this.hasUpper());
            this.pwdRule('包含小写字母', this.hasLower());
            this.pwdRule('包含数字', this.hasDigit());
            this.pwdRule('包含特殊符号', this.hasSymbol());
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 10 });
        }

        if (this.errorMsg) {
          Text(this.errorMsg)
            .fontSize(12)
            .fontColor(AppColors.WARN)
            .margin({ top: 10 })
            .width('100%');
        }

        Button(this.loading ? '提交中...' : (this.isLogin ? '立即登录' : '创建账号'))
          .width('100%')
          .height(48)
          .borderRadius(14)
          .backgroundColor(AppColors.PRIMARY)
          .fontColor('#FFFFFF')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 16 })
          .enabled(!this.loading)
          .onClick((): void => {
            this.handleSubmit();
          });

        Text('跳过 >')
          .fontSize(12)
          .fontColor(AppColors.TEXT_HINT)
          .margin({ top: 14 })
          .onClick((): void => {
            router.pushUrl({ url: 'pages/Index' });
          });
      }
      .width('100%')
      .padding(16)
      .margin({ left: 12, right: 12, top: 12 })
      .backgroundColor(AppColors.CARD_BG)
      .borderRadius(16)
      .shadow({ radius: 8, color: '#15000000', offsetX: 0, offsetY: 4 });

      Blank();
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AppColors.BG);
  }

  @Builder
  tabButton(label: string, active: boolean, onTap: () => void): void {
    Text(label)
      .fontSize(14)
      .fontWeight(active ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(active ? '#FFFFFF' : AppColors.TEXT_SECONDARY)
      .padding({ left: 24, right: 24, top: 10, bottom: 10 })
      .backgroundColor(active ? AppColors.PRIMARY : '#F3F7F4')
      .borderRadius(12)
      .onClick((): void => {
        onTap();
      });
  }

  @Builder
  fieldInput(placeholder: string, value: string, password: boolean, onChange: (value: string) => void): void {
    TextInput({ placeholder: placeholder, text: value })
      .type(password ? InputType.Password : InputType.Normal)
      .width('100%')
      .height(46)
      .backgroundColor('#F3F7F4')
      .borderRadius(12)
      .padding({ left: 14, right: 14 })
      .margin({ top: 10 })
      .onChange((nextValue: string): void => {
        onChange(nextValue);
      });
  }

  @Builder
  pwdRule(label: string, passed: boolean): void {
    Row() {
      Text(passed ? '\u2713' : '\u2717')
        .fontSize(12)
        .fontColor(passed ? AppColors.PRIMARY : AppColors.WARN)
        .margin({ right: 6 });
      Text(label)
        .fontSize(11)
        .fontColor(passed ? AppColors.PRIMARY : AppColors.TEXT_HINT);
    }
    .margin({ top: 3 });
  }
}
