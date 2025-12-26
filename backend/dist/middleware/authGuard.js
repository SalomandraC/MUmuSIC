"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.roleGuard = exports.authGuard = void 0;
const token_service_1 = require("../services/token.service");
const authGuard = (req, res, next) => {
    console.log(`[AuthGuard] Checking auth for ${req.method} ${req.path}`);
    const authHeader = req.headers.authorization;
    if (!authHeader) {
        console.log(`[AuthGuard] No Authorization header`);
        res.status(401).json({ error: 'Необходим заголовок Authorization' });
        return;
    }
    const [, token] = authHeader.split(' ');
    if (!token) {
        console.log(`[AuthGuard] No token in Authorization header`);
        res.status(401).json({ error: 'Не найден токен доступа' });
        return;
    }
    try {
        const payload = (0, token_service_1.verifyAccessToken)(token);
        req.user = payload;
        console.log(`[AuthGuard] Authenticated user: ${payload.sub}`);
        next();
    }
    catch (error) {
        console.log(`[AuthGuard] Token verification failed:`, error);
        if (error.name === 'TokenExpiredError') {
            res.status(401).json({
                error: 'Токен истек',
                code: 'TOKEN_EXPIRED',
                message: 'Используйте refresh token для получения нового access token',
                expiredAt: error.expiredAt
            });
            return;
        }
        res.status(401).json({ error: 'Недействительный или истекший токен' });
    }
};
exports.authGuard = authGuard;
const roleGuard = (roles) => {
    return (req, res, next) => {
        if (!req.user) {
            res.status(401).json({ error: 'Необходима аутентификация' });
            return;
        }
        if (!roles.includes(req.user.role)) {
            res.status(403).json({ error: 'Недостаточно прав' });
            return;
        }
        next();
    };
};
exports.roleGuard = roleGuard;
