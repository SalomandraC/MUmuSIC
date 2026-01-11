import { Request, Response } from "express";
import path from "path";
import fs from "fs";
import { TopChartService } from "./top-chart.service";
import { appConfig } from "../../config/appConfig";

export class TopChartController {
    static async getActiveTopCharts(req: Request, res: Response) {
        try {
            console.log('[TopChartController] Запрос на получение топ-чартов');
            const topCharts = await TopChartService.fetchActiveTopCharts();
            
            if (!topCharts || topCharts.length === 0) {
                console.log('[TopChartController] Топ-чарты не найдены, возвращаем пустой массив');
                return res.status(200).json([]);
            }
            
            console.log(`[TopChartController] Получено топ-чартов: ${topCharts.length}`);
            
            const normalizeStoragePath = (p: string) => {
                if (!p) return '';
                return p.replace(/^\/(storage)?\/?/, '');
            };

            const host = req.get('host') || `localhost:${appConfig.port}`;
            const protocol = req.protocol || 'http';

            const formattedCharts = topCharts.map((chart: any) => {
                let createdAt: string;
                try {
                    if (chart.created_at instanceof Date) {
                        createdAt = chart.created_at.toISOString();
                    } else if (chart.created_at) {
                        createdAt = new Date(chart.created_at).toISOString();
                    } else {
                        createdAt = new Date().toISOString();
                    }
                } catch (e) {
                    console.warn('[TopChartController] Ошибка форматирования created_at:', e);
                    createdAt = new Date().toISOString();
                }
                
                // Формируем URL для файла, как в TracksService
                const normalizedPath = normalizeStoragePath((chart.file_path || '').replace(/\\/g, '/'));
                const fileUrl = normalizedPath ? `${protocol}://${host}/storage/${normalizedPath}` : '';
                
                // Stream URL для воспроизведения
                const streamUrl = chart.id ? `${protocol}://${host}/top-charts/${chart.id}/stream` : '';
                
                return {
                    id: chart.id,
                    title: chart.title || '',
                    artist: chart.artist || '',
                    file_path: chart.file_path || '',
                    file_format: chart.file_format || '',
                    duration: chart.duration || 0,
                    file_size: chart.file_size || 0,
                    is_active: chart.is_active ?? true,
                    play_count: chart.play_count || 0,
                    created_at: createdAt,
                    url: fileUrl,
                    streamUrl: streamUrl
                };
            });
            
            console.log('[TopChartController] Отправляем ответ с топ-чартами');
            return res.status(200).json(formattedCharts);
        } catch (error: any) {
            console.error("[TopChartController] Ошибка при получении топ-чартов:", error);
            console.error("[TopChartController] Stack trace:", error?.stack);
            return res.status(500).json({ error: "Внутренняя ошибка сервера" });
        }
    }
    
    static async streamTrack(req: Request, res: Response) {
        try {
            const trackId = Number(req.params.id);
            if (!trackId) {
                return res.status(400).json({ error: 'Неверный ID трека' });
            }
            
            console.log(`[TopChartController] Запрос на стрим трека ID: ${trackId}`);
            
            // Получаем трек из БД
            const track = await TopChartService.getTrackById(trackId);
            
            if (!track || !track.file_path) {
                return res.status(404).json({ error: 'Трек не найден' });
            }
            
            const relPath = (track.file_path || '').replace(/\\/g, '/').replace(/^\/(storage)?\/?/, '');
            const filePath = path.join(appConfig.storageRoot, relPath);
            if (!fs.existsSync(filePath)) {
                console.error(`[TopChartController] Файл не найден: ${filePath}`);
                return res.status(404).json({ error: 'Файл не найден' });
            }
            
            const stat = fs.statSync(filePath);
            const fileSize = stat.size;
            const range = req.headers.range;
            
            if (range) {
                const parts = range.replace(/bytes=/, "").split("-");
                const start = parseInt(parts[0], 10);
                const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
                const chunksize = (end - start) + 1;
                const file = fs.createReadStream(filePath, { start, end });
                const head = {
                    'Content-Range': `bytes ${start}-${end}/${fileSize}`,
                    'Accept-Ranges': 'bytes',
                    'Content-Length': chunksize,
                    'Content-Type': 'audio/mpeg',
                };
                res.writeHead(206, head);
                file.pipe(res);
            } else {
                const head = {
                    'Content-Length': fileSize,
                    'Content-Type': 'audio/mpeg',
                };
                res.writeHead(200, head);
                fs.createReadStream(filePath).pipe(res);
            }
        } catch (error: any) {
            console.error("[TopChartController] Ошибка при стриме трека:", error);
            if (!res.headersSent) {
                return res.status(500).json({ error: "Внутренняя ошибка сервера" });
            }
        }
    }
}