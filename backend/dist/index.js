"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const dotenv_1 = __importDefault(require("dotenv"));
dotenv_1.default.config();
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const morgan_1 = __importDefault(require("morgan"));
const swagger_ui_express_1 = __importDefault(require("swagger-ui-express"));
const swagger_1 = require("./config/swagger");
const appConfig_1 = require("./config/appConfig");
const auth_routes_1 = __importDefault(require("./modules/auth/auth.routes"));
const errorHandler_1 = require("./middleware/errorHandler");
const app = (0, express_1.default)();
const allowedOrigins = [
    'http://localhost:3000',
    'https://f4x1pn2ft.localto.net',
    'http://d91098wj.beget.tech'
];
// Middleware
if (appConfig_1.appConfig.nodeEnv === 'development') {
    app.use((0, morgan_1.default)('dev'));
}
else {
    app.use((0, morgan_1.default)('combined'));
}
app.use((0, cors_1.default)({
    origin: (origin, callback) => {
        if (!origin)
            return callback(null, true);
        if (allowedOrigins.includes(origin)) {
            callback(null, true);
        }
        else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: [
        'Content-Type',
        'Authorization',
        'localtonet-skip-warning'
    ],
    credentials: true,
    optionsSuccessStatus: 200
}));
app.options('*', (0, cors_1.default)());
app.use(express_1.default.json());
app.use(express_1.default.urlencoded({ extended: true }));
app.use('/api-docs', swagger_ui_express_1.default.serve, swagger_ui_express_1.default.setup(swagger_1.swaggerSpec, {
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'Study Practice API Documentation'
}));
// Роуты
app.use('/auth', auth_routes_1.default);
// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
});
// Обработка 404
app.use(errorHandler_1.notFoundHandler);
// Централизованная обработка ошибок
app.use(errorHandler_1.errorHandler);
// Запуск сервера
app.listen(Number(appConfig_1.appConfig.port), '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${appConfig_1.appConfig.port}`);
    console.log(`Swagger docs available at http://0.0.0.0:${appConfig_1.appConfig.port}/api-docs`);
});
