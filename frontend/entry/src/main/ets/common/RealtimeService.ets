import { ApiService } from './ApiService';
import { ApiConstants } from './Constants';
import { AlertLog, AlertLogListResponse, PestRealtimeItem, SensorData } from '../model/DataModels';

type SensorDataHandler = (data: SensorData) => void;
type AlertHandler = (items: AlertLog[]) => void;
type PestHandler = (data: PestRealtimeItem) => void;

class RealtimeService {
  private sensorHandlers: SensorDataHandler[] = [];
  private alertHandlers: AlertHandler[] = [];
  private pestHandlers: PestHandler[] = [];
  private pollTimer: number = -1;
  private polling: boolean = false;
  private readonly pollIntervalMs: number = 5000;

  connect(): void {
    if (this.pollTimer !== -1) {
      return;
    }
    this.pollTimer = setInterval((): void => {
      this.pollOnce();
    }, this.pollIntervalMs) as number;
    this.pollOnce();
  }

  disconnect(): void {
    if (this.pollTimer !== -1) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
    this.polling = false;
  }

  subscribeSensorData(handler: SensorDataHandler): () => void {
    this.sensorHandlers.push(handler);
    this.connect();
    return (): void => {
      this.sensorHandlers = this.sensorHandlers.filter((h: SensorDataHandler): boolean => h !== handler);
      if (this.sensorHandlers.length === 0 && this.alertHandlers.length === 0 && this.pestHandlers.length === 0) {
        this.disconnect();
      }
    };
  }

  subscribeAlerts(handler: AlertHandler): () => void {
    this.alertHandlers.push(handler);
    this.connect();
    return (): void => {
      this.alertHandlers = this.alertHandlers.filter((h: AlertHandler): boolean => h !== handler);
      if (this.sensorHandlers.length === 0 && this.alertHandlers.length === 0 && this.pestHandlers.length === 0) {
        this.disconnect();
      }
    };
  }

  subscribePestRealtime(handler: PestHandler): () => void {
    this.pestHandlers.push(handler);
    this.connect();
    return (): void => {
      this.pestHandlers = this.pestHandlers.filter((h: PestHandler): boolean => h !== handler);
      if (this.sensorHandlers.length === 0 && this.alertHandlers.length === 0 && this.pestHandlers.length === 0) {
        this.disconnect();
      }
    };
  }

  private async pollOnce(): Promise<void> {
    if (this.polling) {
      return;
    }
    if (this.sensorHandlers.length === 0 && this.alertHandlers.length === 0 && this.pestHandlers.length === 0) {
      return;
    }
    this.polling = true;
    try {
      if (this.sensorHandlers.length > 0) {
        const sensor: SensorData = await ApiService.get<SensorData>(ApiConstants.SENSOR_LATEST);
        this.sensorHandlers.forEach((handler: SensorDataHandler): void => {
          handler(sensor);
        });
      }

      if (this.alertHandlers.length > 0) {
        const query = new Map<string, string>([
          ['page', '1'],
          ['page_size', '5'],
        ]);
        const alertRes: AlertLogListResponse = await ApiService.get<AlertLogListResponse>(ApiConstants.ALERT_LOGS, query);
        const items: AlertLog[] = alertRes.items || [];
        if (items.length > 0) {
          this.alertHandlers.forEach((handler: AlertHandler): void => {
            handler(items);
          });
        }
      }

      if (this.pestHandlers.length > 0) {
        try {
          const pest: PestRealtimeItem = await ApiService.get<PestRealtimeItem>(ApiConstants.AI_PEST_LATEST);
          this.pestHandlers.forEach((handler: PestHandler): void => {
            handler(pest);
          });
        } catch (_e) {
          // Ignore 404 when no realtime pest data yet.
        }
      }
    } catch (_e) {
      // Ignore polling errors and retry next tick.
    } finally {
      this.polling = false;
    }
  }
}

export const realtimeService: RealtimeService = new RealtimeService();
