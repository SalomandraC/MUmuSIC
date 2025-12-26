"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyRefreshToken = exports.verifyAccessToken = exports.generateRefreshToken = exports.generateAccessToken = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const appConfig_1 = require("../config/appConfig");
const signToken = (payload, secret, expiresIn, type) => {
    return jsonwebtoken_1.default.sign({
        ...payload,
        type,
    }, secret, { expiresIn });
};
const verifyToken = (token, secret) => {
    const decoded = jsonwebtoken_1.default.verify(token, secret);
    if (typeof decoded === 'string') {
        throw new Error('Неверный формат токена');
    }
    const payload = decoded;
    if (typeof payload.type === 'undefined') {
        throw new Error('Токен не содержит тип');
    }
    return payload;
};
const generateAccessToken = (payload) => signToken(payload, appConfig_1.appConfig.jwt.accessSecret, appConfig_1.appConfig.jwt.accessTtl, 'access');
exports.generateAccessToken = generateAccessToken;
const generateRefreshToken = (payload) => signToken(payload, appConfig_1.appConfig.jwt.refreshSecret, appConfig_1.appConfig.jwt.refreshTtl, 'refresh');
exports.generateRefreshToken = generateRefreshToken;
const verifyAccessToken = (token) => {
    const decoded = verifyToken(token, appConfig_1.appConfig.jwt.accessSecret);
    if (decoded.type !== 'access') {
        throw new Error('Invalid access token type');
    }
    return decoded;
};
exports.verifyAccessToken = verifyAccessToken;
const verifyRefreshToken = (token) => {
    const decoded = verifyToken(token, appConfig_1.appConfig.jwt.refreshSecret);
    if (decoded.type !== 'refresh') {
        throw new Error('Invalid refresh token type');
    }
    return decoded;
};
exports.verifyRefreshToken = verifyRefreshToken;
