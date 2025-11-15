"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const asyncHandler_1 = require("../../middleware/asyncHandler");
const authGuard_1 = require("../../middleware/authGuard");
const auth_controller_1 = require("./auth.controller");
const router = (0, express_1.Router)();
/**
 * @swagger
 * tags:
 *   name: Auth
 *   description: Аутентификация и управление пользователями
 */
/**
 * @swagger
 * /auth/register:
 *   post:
 *     summary: Регистрация нового пользователя
 *     tags: [Auth]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             $ref: '#/components/schemas/RegisterRequest'
 *     responses:
 *       201:
 *         description: Пользователь создан
 */
router.post('/register', (0, asyncHandler_1.asyncHandler)(auth_controller_1.AuthController.register));
/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Вход пользователя
 *     tags: [Auth]
 */
router.post('/login', (0, asyncHandler_1.asyncHandler)(auth_controller_1.AuthController.login));
/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Выход пользователя
 *     tags: [Auth]
 */
router.post('/logout', (0, asyncHandler_1.asyncHandler)(auth_controller_1.AuthController.logout));
/**
 * @swagger
 * /auth/me:
 *   get:
 *     summary: Получить текущего пользователя
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 */
router.get('/me', authGuard_1.authGuard, (0, asyncHandler_1.asyncHandler)(auth_controller_1.AuthController.me));
/**
 * @swagger
 * /auth/refresh-token:
 *   post:
 *     summary: Обновление токенов
 *     tags: [Auth]
 */
router.post('/refresh-token', (0, asyncHandler_1.asyncHandler)(auth_controller_1.AuthController.refreshToken));
/**
 * @swagger
 * /auth/change-password:
 *   post:
 *     summary: Смена пароля
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 */
router.post('/change-password', authGuard_1.authGuard, (0, asyncHandler_1.asyncHandler)(auth_controller_1.AuthController.changePassword));
/**
 * @swagger
 * /auth/reset-password/request:
 *   post:
 *     summary: Запрос на сброс пароля
 *     tags: [Auth]
 */
router.post('/reset-password/request', (0, asyncHandler_1.asyncHandler)(auth_controller_1.AuthController.resetPasswordRequest));
/**
 * @swagger
 * /auth/reset-password/confirm:
 *   post:
 *     summary: Подтверждение сброса пароля
 *     tags: [Auth]
 */
router.post('/reset-password/confirm', (0, asyncHandler_1.asyncHandler)(auth_controller_1.AuthController.resetPasswordConfirm));
/**
 * @swagger
 * /auth/guest-session:
 *   post:
 *     summary: Создать гостевую сессию
 *     tags: [Auth]
 */
router.post('/guest-session', (0, asyncHandler_1.asyncHandler)(auth_controller_1.AuthController.createGuestSession));
/**
 * @swagger
 * /auth/guest-session/validate:
 *   post:
 *     summary: Проверить гостевую сессию
 *     tags: [Auth]
 */
router.post('/guest-session/validate', (0, asyncHandler_1.asyncHandler)(auth_controller_1.AuthController.validateGuestSession));
exports.default = router;
