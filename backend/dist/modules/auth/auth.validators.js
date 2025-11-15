"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resetPasswordConfirmSchema = exports.resetPasswordRequestSchema = exports.changePasswordSchema = exports.refreshTokenSchema = exports.guestSessionValidateSchema = exports.loginSchema = exports.registerSchema = void 0;
const zod_1 = require("zod");
exports.registerSchema = zod_1.z.object({
    username: zod_1.z.string().min(3).max(50),
    email: zod_1.z.string().email(),
    password: zod_1.z.string().min(8).max(100),
});
exports.loginSchema = zod_1.z.object({
    email: zod_1.z.string().email(),
    password: zod_1.z.string().min(8).max(100),
});
exports.guestSessionValidateSchema = zod_1.z.object({
    sessionId: zod_1.z.string().min(10),
});
exports.refreshTokenSchema = zod_1.z.object({
    refreshToken: zod_1.z.string().min(10),
});
exports.changePasswordSchema = zod_1.z.object({
    currentPassword: zod_1.z.string().min(8).max(100),
    newPassword: zod_1.z.string().min(8).max(100),
});
exports.resetPasswordRequestSchema = zod_1.z.object({
    email: zod_1.z.string().email(),
});
exports.resetPasswordConfirmSchema = zod_1.z.object({
    token: zod_1.z.string().min(10),
    newPassword: zod_1.z.string().min(8).max(100),
});
