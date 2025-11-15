"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const crypto_1 = require("crypto");
const auth_repository_1 = require("./auth.repository");
const password_service_1 = require("../../services/password.service");
const token_service_1 = require("../../services/token.service");
const appConfig_1 = require("../../config/appConfig");
const httpError_1 = require("../../utils/httpError");
const toSafeUser = (user) => ({
    id: user.id,
    username: user.username,
    email: user.email,
    role: user.role,
    guestSessionId: user.guest_session_id,
    createdAt: user.created_at,
    updatedAt: user.updated_at,
});
const buildTokens = (user) => {
    const payload = {
        sub: user.id,
        role: user.role,
        tokenVersion: user.updated_at?.getTime() ?? Date.now(),
    };
    return {
        accessToken: (0, token_service_1.generateAccessToken)(payload),
        refreshToken: (0, token_service_1.generateRefreshToken)(payload),
    };
};
const toGuestSessionSafe = (session) => ({
    sessionId: session.session_id,
    lastActivity: session.last_activity,
    accessCount: session.access_count,
    createdAt: session.created_at,
});
class AuthService {
    static async register(input) {
        const [existingByEmail, existingByUsername] = await Promise.all([
            auth_repository_1.AuthRepository.findUserByEmail(input.email),
            auth_repository_1.AuthRepository.findUserByUsername(input.username),
        ]);
        if (existingByEmail) {
            throw (0, httpError_1.createHttpError)(409, 'Пользователь с таким email уже существует');
        }
        if (existingByUsername) {
            throw (0, httpError_1.createHttpError)(409, 'Пользователь с таким username уже существует');
        }
        const passwordHash = await (0, password_service_1.hashPassword)(input.password);
        const user = await auth_repository_1.AuthRepository.createUser(input.username, input.email.toLowerCase().trim(), passwordHash);
        return {
            user: toSafeUser(user),
            tokens: buildTokens(user),
        };
    }
    static async login(input) {
        const user = await auth_repository_1.AuthRepository.findUserByEmail(input.email);
        if (!user) {
            throw (0, httpError_1.createHttpError)(401, 'Неверные учетные данные');
        }
        const isPasswordValid = await (0, password_service_1.comparePassword)(input.password, user.password_hash);
        if (!isPasswordValid) {
            throw (0, httpError_1.createHttpError)(401, 'Неверные учетные данные');
        }
        return {
            user: toSafeUser(user),
            tokens: buildTokens(user),
        };
    }
    static async refreshTokens(refreshToken) {
        const payload = (0, token_service_1.verifyRefreshToken)(refreshToken);
        const userId = Number(payload.sub);
        if (!userId) {
            throw (0, httpError_1.createHttpError)(401, 'Недействительный токен');
        }
        const user = await auth_repository_1.AuthRepository.findUserById(userId);
        if (!user) {
            throw (0, httpError_1.createHttpError)(404, 'Пользователь не найден');
        }
        return buildTokens(user);
    }
    static async getProfile(userId) {
        const user = await auth_repository_1.AuthRepository.findUserById(userId);
        if (!user) {
            throw (0, httpError_1.createHttpError)(404, 'Пользователь не найден');
        }
        return toSafeUser(user);
    }
    static async createGuestSession() {
        const sessionId = (0, crypto_1.randomUUID)();
        const session = await auth_repository_1.AuthRepository.createGuestSession(sessionId);
        return toGuestSessionSafe(session);
    }
    static async validateGuestSession(input) {
        const session = await auth_repository_1.AuthRepository.findGuestSession(input.sessionId);
        if (!session) {
            throw (0, httpError_1.createHttpError)(404, 'Гостевая сессия не найдена');
        }
        const ttlMs = appConfig_1.appConfig.guestSessions.ttlMinutes * 60 * 1000;
        const isExpired = Date.now() - new Date(session.last_activity).getTime() > ttlMs;
        if (isExpired) {
            await auth_repository_1.AuthRepository.deleteGuestSession(input.sessionId);
            throw (0, httpError_1.createHttpError)(410, 'Гостевая сессия истекла');
        }
        const updatedSession = await auth_repository_1.AuthRepository.touchGuestSession(input.sessionId);
        return toGuestSessionSafe(updatedSession);
    }
    static async changePassword(input) {
        const user = await auth_repository_1.AuthRepository.findUserById(input.userId);
        if (!user) {
            throw (0, httpError_1.createHttpError)(404, 'Пользователь не найден');
        }
        const isPasswordValid = await (0, password_service_1.comparePassword)(input.currentPassword, user.password_hash);
        if (!isPasswordValid) {
            throw (0, httpError_1.createHttpError)(400, 'Текущий пароль неверен');
        }
        if (input.currentPassword === input.newPassword) {
            throw (0, httpError_1.createHttpError)(400, 'Новый пароль не должен совпадать с текущим');
        }
        const newHash = await (0, password_service_1.hashPassword)(input.newPassword);
        const updatedUser = await auth_repository_1.AuthRepository.updateUserPassword(user.id, newHash);
        return toSafeUser(updatedUser);
    }
    static async resetPasswordRequest(input) {
        const user = await auth_repository_1.AuthRepository.findUserByEmail(input.email);
        if (!user) {
            throw (0, httpError_1.createHttpError)(404, 'Пользователь с таким email не найден');
        }
        const token = (0, token_service_1.generatePasswordResetToken)({
            sub: user.id,
            role: user.role,
            tokenVersion: user.updated_at?.getTime(),
        });
        return {
            token,
            message: 'Токен для сброса пароля сгенерирован. Отправьте его пользователю по email.',
        };
    }
    static async resetPasswordConfirm(input) {
        const payload = (0, token_service_1.verifyPasswordResetToken)(input.token);
        const userId = Number(payload.sub);
        if (!userId) {
            throw (0, httpError_1.createHttpError)(400, 'Недействительный токен');
        }
        const user = await auth_repository_1.AuthRepository.findUserById(userId);
        if (!user) {
            throw (0, httpError_1.createHttpError)(404, 'Пользователь не найден');
        }
        const passwordHash = await (0, password_service_1.hashPassword)(input.newPassword);
        await auth_repository_1.AuthRepository.updateUserPassword(user.id, passwordHash);
        return { message: 'Пароль успешно обновлен' };
    }
    static async logout() {
        return { message: 'Выход выполнен' };
    }
}
exports.AuthService = AuthService;
