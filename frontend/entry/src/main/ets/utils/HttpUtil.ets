import http from '@ohos.net.http';

// 采用模拟器专用 IP 以直连本机的 Python 8000 端口
const BASE_URL = 'http://10.0.2.2:8000'; 

export class HttpUtil {
  /**
   * 测试连通性：一键请求后端的根目录 /
   * @returns 承诺返回后端响应的 JSON 字符串
   */
  static async pingServer(): Promise<string> {
    let httpRequest = http.createHttp();
    try {
      let response = await httpRequest.request(
        `${BASE_URL}/`, 
        {
          method: http.RequestMethod.GET,
          header: { 'Content-Type': 'application/json' },
          readTimeout: 5000,
          connectTimeout: 5000 
        }
      );
      
      if (response.responseCode === 200) {
        return `✅ 联调成功！收到数据: ${response.result}`;
      } else {
        return `❌ 通信异常_HTTP(${response.responseCode})`;
      }
    } catch (err) {
      return `❌ 全链路崩溃，可能IP不通或后端未开: ${JSON.stringify(err)}`;
    } finally {
      httpRequest.destroy();
    }
  }
}
