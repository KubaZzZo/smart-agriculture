// 智慧农业控制系统 - API 服务封装
import { http } from '@kit.NetworkKit';
import { ApiConstants } from './Constants';

export class ApiService {
  static async get<T>(path: string, params?: Record<string, string>): Promise<T> {
    let url = ApiConstants.BASE_URL + path;
    if (params) {
      const query = Object.keys(params).map(k => `${k}=${encodeURIComponent(params[k])}`).join('&');
      url += '?' + query;
    }
    const httpRequest = http.createHttp();
    try {
      const token = AppStorage.get<string>('token') || '';
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : ''
        },
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as T;
        return result;
      }
      throw new Error(`HTTP ${response.responseCode}`);
    } finally {
      httpRequest.destroy();
    }
  }

  static async post<T>(path: string, body?: object): Promise<T> {
    const url = ApiConstants.BASE_URL + path;
    const httpRequest = http.createHttp();
    try {
      const token = AppStorage.get<string>('token') || '';
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : ''
        },
        extraData: body ? JSON.stringify(body) : '',
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as T;
        return result;
      }
      throw new Error(`HTTP ${response.responseCode}`);
    } finally {
      httpRequest.destroy();
    }
  }

  static async put<T>(path: string, body?: object): Promise<T> {
    const url = ApiConstants.BASE_URL + path;
    const httpRequest = http.createHttp();
    try {
      const token = AppStorage.get<string>('token') || '';
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.PUT,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : ''
        },
        extraData: body ? JSON.stringify(body) : '',
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as T;
        return result;
      }
      throw new Error(`HTTP ${response.responseCode}`);
    } finally {
      httpRequest.destroy();
    }
  }

  static async delete<T>(path: string): Promise<T> {
    const url = ApiConstants.BASE_URL + path;
    const httpRequest = http.createHttp();
    try {
      const token = AppStorage.get<string>('token') || '';
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.DELETE,
        header: {
          'Content-Type': 'application/json',
          'Authorization': token ? `Bearer ${token}` : ''
        },
        connectTimeout: 10000,
        readTimeout: 15000
      });
      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as T;
        return result;
      }
      throw new Error(`HTTP ${response.responseCode}`);
    } finally {
      httpRequest.destroy();
    }
  }

  // 保存登录信息
  static saveToken(token: string, username: string, role: string): void {
    AppStorage.setOrCreate('token', token);
    AppStorage.setOrCreate('username', username);
    AppStorage.setOrCreate('userRole', role);
    AppStorage.setOrCreate('isLoggedIn', true);
  }

  // 清除登录信息
  static clearToken(): void {
    AppStorage.setOrCreate('token', '');
    AppStorage.setOrCreate('username', '');
    AppStorage.setOrCreate('userRole', '');
    AppStorage.setOrCreate('isLoggedIn', false);
  }

  // 检查是否已登录
  static isLoggedIn(): boolean {
    return AppStorage.get<boolean>('isLoggedIn') || false;
  }
}
