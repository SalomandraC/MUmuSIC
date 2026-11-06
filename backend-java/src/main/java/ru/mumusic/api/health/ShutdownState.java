package ru.mumusic.api.health;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.SmartLifecycle;
import org.springframework.stereotype.Component;
import ru.mumusic.api.config.AppConfig;

/**
 * При остановке (SIGTERM) первым делом переключает /ready на 503, ждёт, пока балансировщик
 * уберёт эту копию (2 с в production), и только потом Spring перестаёт принимать запросы
 * и дожидается текущих (server.shutdown=graceful).
 */
@Component
public class ShutdownState implements SmartLifecycle {

    private static final Logger log = LoggerFactory.getLogger(ShutdownState.class);

    private final long drainDelayMs;
    private volatile boolean running;
    private volatile boolean shuttingDown;

    public ShutdownState(AppConfig config) {
        this.drainDelayMs = config.isProduction() ? 2000 : 0;
    }

    public boolean isShuttingDown() {
        return shuttingDown;
    }

    @Override
    public void start() {
        running = true;
    }

    @Override
    public void stop() {
        shuttingDown = true;
        log.info("Получен сигнал остановки, дожидаемся текущих запросов");
        if (drainDelayMs > 0) {
            try {
                Thread.sleep(drainDelayMs);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
        running = false;
    }

    @Override
    public boolean isRunning() {
        return running;
    }

    /** Останавливается раньше веб-сервера (у него фаза SmartLifecycle.DEFAULT_PHASE - 1024) */
    @Override
    public int getPhase() {
        return Integer.MAX_VALUE;
    }
}
