import { TopChartRepository } from './top-chart.repository';

export class TopChartService {
    static async fetchActiveTopCharts() {
        const topCharts = await TopChartRepository.getActiveTopCharts();
        return topCharts;
    }
    
    static async getTrackById(trackId: number) {
        const topCharts = await TopChartRepository.getActiveTopCharts();
        return topCharts?.find((track: any) => track.id === trackId) || null;
    }
}