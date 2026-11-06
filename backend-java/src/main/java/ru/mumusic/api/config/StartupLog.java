package ru.mumusic.api.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import java.nio.file.Files;

@Component
public class StartupLog {

    private static final Logger log = LoggerFactory.getLogger(StartupLog.class);

    private final AppConfig config;
    private final Environment env;

    public StartupLog(AppConfig config, Environment env) {
        this.config = config;
        this.env = env;
    }

    @EventListener(ApplicationReadyEvent.class)
    public void ready() {
        String port = env.getProperty("local.server.port", env.getProperty("server.port", "5050"));
        log.info("Сервер запущен на http://localhost:{} ({}), документация /api-docs", port, config.env());
        log.info("Хранилище: {} ({})", config.storageRoot(),
                Files.exists(config.storageRoot()) ? "найдено" : "НЕ НАЙДЕНО, проверьте STORAGE_ROOT");
    }
}
