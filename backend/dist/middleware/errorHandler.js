"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.notFoundHandler = exports.errorHandler = void 0;
const zod_1 = require("zod");
const errorHandler = (err, req, res, next) => {
    if (err instanceof zod_1.ZodError) {
        res.status(400).json({
            error: 'Ошибка валидации',
            issues: err.issues,
        });
        return;
    }
    const statusCode = err.statusCode || 500;
    const message = err.message || 'Внутренняя ошибка сервера';
    console.error('Error:', {
        statusCode,
        message,
        stack: process.env.NODE_ENV === 'development' ? err.stack : undefined,
        path: req.path,
        method: req.method,
    });
    res.status(statusCode).json({
        error: message,
        ...(process.env.NODE_ENV === 'development' && { stack: err.stack }),
    });
    return;
};
exports.errorHandler = errorHandler;
const notFoundHandler = (req, res) => {
    console.error(`\n[404] Route not found: ${req.method} ${req.path}`);
    console.error(`  Original URL: ${req.originalUrl}`);
    console.error(`  Base URL: ${req.baseUrl}`);
    console.error(`  Content-Type: ${req.headers['content-type']}`);
    console.error(`  Authorization: ${req.headers.authorization ? 'present' : 'missing'}`);
    console.error(`  Registered routes should include: POST /tracks`);
    res.status(404).json({
        error: `Маршрут ${req.method} ${req.path} не найден`,
    });
};
exports.notFoundHandler = notFoundHandler;
