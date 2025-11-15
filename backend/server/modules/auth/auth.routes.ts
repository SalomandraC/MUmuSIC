import { Router } from 'express';
import { asyncHandler } from '../../middleware/asyncHandler';
import { authGuard } from '../../middleware/authGuard';
import { AuthController } from './auth.controller';

const router = Router();

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
router.post('/register', asyncHandler(AuthController.register));

/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Вход пользователя
 *     tags: [Auth]
 */
router.post('/login', asyncHandler(AuthController.login));

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Выход пользователя
 *     tags: [Auth]
 */
router.post('/logout', asyncHandler(AuthController.logout));

/**
 * @swagger
 * /auth/me:
 *   get:
 *     summary: Получить текущего пользователя
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 */
router.get('/me', authGuard, asyncHandler(AuthController.me));

/**
 * @swagger
 * /auth/refresh-token:
 *   post:
 *     summary: Обновление токенов
 *     tags: [Auth]
 */
router.post('/refresh-token', asyncHandler(AuthController.refreshToken));

/**
 * @swagger
 * /auth/change-password:
 *   post:
 *     summary: Смена пароля
 *     tags: [Auth]
 *     security:
 *       - bearerAuth: []
 */
router.post('/change-password', authGuard, asyncHandler(AuthController.changePassword));

/**
 * @swagger
 * /auth/reset-password/request:
 *   post:
 *     summary: Запрос на сброс пароля
 *     tags: [Auth]
 */
router.post('/reset-password/request', asyncHandler(AuthController.resetPasswordRequest));

/**
 * @swagger
 * /auth/reset-password/confirm:
 *   post:
 *     summary: Подтверждение сброса пароля
 *     tags: [Auth]
 */
router.post('/reset-password/confirm', asyncHandler(AuthController.resetPasswordConfirm));

/**
 * @swagger
 * /auth/guest-session:
 *   post:
 *     summary: Создать гостевую сессию
 *     tags: [Auth]
 */
router.post('/guest-session', asyncHandler(AuthController.createGuestSession));

/**
 * @swagger
 * /auth/guest-session/validate:
 *   post:
 *     summary: Проверить гостевую сессию
 *     tags: [Auth]
 */
router.post('/guest-session/validate', asyncHandler(AuthController.validateGuestSession));

export default router;

