import sql from '../../config/db';
import { TopChartRecord } from './top-chart.types';

export class TopChartRepository {
    static async getActiveTopCharts(): Promise<TopChartRecord[] | null> {
        try {
            console.log('[TopChartRepository] Выполняем запрос к БД для получения топ-чартов');
            const result = await sql`
                SELECT * FROM public.guest_tracks 
                WHERE is_active = true 
                ORDER BY play_count DESC 
                LIMIT 10
            `;

            if (!result || result.length === 0) {
                console.log('[TopChartRepository] Топ-чарты не найдены в БД');
                return null;
            }

            console.log(`[TopChartRepository] Получено ${result.length} записей из БД`);

            return result.map((row: any) => ({
                id: row.id,
                title: row.title || '',
                artist: row.artist || '',
                file_path: row.file_path || '',
                file_format: row.file_format || '',
                duration: row.duration || 0,
                file_size: row.file_size || 0,
                is_active: row.is_active ?? true,
                play_count: row.play_count || 0,
                created_at: row.created_at || new Date(),
            })) as TopChartRecord[];
        } catch (error) {
            console.error('[TopChartRepository] Ошибка при запросе к БД:', error);
            throw error;
        }
    }
}