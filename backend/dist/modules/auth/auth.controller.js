"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthController = void 0;
const auth_service_1 = require("./auth.service");
const auth_validators_1 = require("./auth.validators");
class AuthController {
    static async register(req, res) {
        const payload = auth_validators_1.registerSchema.parse(req.body);
        const result = await auth_service_1.AuthService.register(payload);
        res.status(201).json(result);
    }
    static async login(req, res) {
        const payload = auth_validators_1.loginSchema.parse(req.body);
        const result = await auth_service_1.AuthService.login(payload);
        res.json(result);
    }
    static async refreshToken(req, res) {
        const { refreshToken } = auth_validators_1.refreshTokenSchema.parse(req.body);
        const tokens = await auth_service_1.AuthService.refreshTokens(refreshToken);
        res.json(tokens);
    }
    static async me(req, res) {
        const userId = Number(req.user?.sub);
        if (!userId) {
            res.status(401).json({ error: 'Необходима аутентификация' });
            return;
        }
        const user = await auth_service_1.AuthService.getProfile(userId);
        res.json({ user });
    }
    static async logout(req, res) {
        const result = await auth_service_1.AuthService.logout();
        res.json(result);
    }
    static async createGuestSession(req, res) {
        const session = await auth_service_1.AuthService.createGuestSession();
        res.status(201).json(session);
    }
    static async validateGuestSession(req, res) {
        const payload = auth_validators_1.guestSessionValidateSchema.parse(req.body);
        const session = await auth_service_1.AuthService.validateGuestSession(payload);
        res.json(session);
    }
    static async changePassword(req, res) {
        const payload = auth_validators_1.changePasswordSchema.parse(req.body);
        const userId = Number(req.user?.sub);
        if (!userId) {
            res.status(401).json({ error: 'Необходима аутентификация' });
            return;
        }
        const user = await auth_service_1.AuthService.changePassword({
            ...payload,
            userId,
        });
        res.json({ user });
    }
    static async resetPasswordRequest(req, res) {
        const payload = auth_validators_1.resetPasswordRequestSchema.parse(req.body);
        const result = await auth_service_1.AuthService.resetPasswordRequest(payload);
        res.json(result);
    }
    static async resetPasswordConfirm(req, res) {
        const payload = auth_validators_1.resetPasswordConfirmSchema.parse(req.body);
        const result = await auth_service_1.AuthService.resetPasswordConfirm(payload);
        res.json(result);
    }
}
exports.AuthController = AuthController;
