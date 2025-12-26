"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const auth_repository_1 = require("./auth.repository");
const password_service_1 = require("../../services/password.service");
const token_service_1 = require("../../services/token.service");
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
    static async logout() {
        return { message: 'Выход выполнен' };
    }
}
exports.AuthService = AuthService;
