"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const db_1 = __importDefault(require("../../config/db"));
const asyncHandler_1 = require("../../middleware/asyncHandler");
const router = (0, express_1.Router)();
/**
 * @swagger
 * tags:
 *   name: Debug
 *   description: Вспомогательные эндпоинты для проверки подключения к БД
 */
/**
 * @swagger
 * /debug/tracks:
 *   get:
 *     summary: Получить все треки (проверка подключения к БД)
 *     tags: [Debug]
 *     responses:
 *       200:
 *         description: Список треков
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '#/components/schemas/Track'
 *       500:
 *         description: Ошибка подключения/запроса к БД
 */
router.get('/tracks', (0, asyncHandler_1.asyncHandler)(async (req, res) => {
    const rows = await (0, db_1.default) `
    SELECT id, user_id, title, artist, album, duration, file_path, file_format, file_size, notes, is_public, created_at
    FROM tracks
    ORDER BY id
  `;
    res.json(rows);
}));
exports.default = router;
