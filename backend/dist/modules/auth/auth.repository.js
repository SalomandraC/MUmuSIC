"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthRepository = void 0;
const db_1 = __importDefault(require("../../config/db"));
const mapUser = (record) => ({
    id: record.id,
    username: record.username,
    email: record.email,
    password_hash: record.password_hash,
    role: record.role,
    guest_session_id: record.guest_session_id,
    created_at: record.created_at,
    updated_at: record.updated_at,
});
const mapGuestSession = (record) => ({
    session_id: record.session_id,
    last_activity: record.last_activity,
    access_count: record.access_count,
    created_at: record.created_at,
});
class AuthRepository {
    static async findUserByEmail(email) {
        const result = await (0, db_1.default) `
      SELECT *
      FROM users
      WHERE lower(email) = lower(${email})
      LIMIT 1
    `;
        if (result.length === 0)
            return null;
        return mapUser(result[0]);
    }
    static async findUserByUsername(username) {
        const result = await (0, db_1.default) `
      SELECT *
      FROM users
      WHERE lower(username) = lower(${username})
      LIMIT 1
    `;
        if (result.length === 0)
            return null;
        return mapUser(result[0]);
    }
    static async findUserById(id) {
        const result = await (0, db_1.default) `
      SELECT *
      FROM users
      WHERE id = ${id}
      LIMIT 1
    `;
        if (result.length === 0)
            return null;
        return mapUser(result[0]);
    }
    static async createUser(username, email, passwordHash, role = 'user') {
        const result = await (0, db_1.default) `
      INSERT INTO users (username, email, password_hash, role)
      VALUES (${username}, ${email}, ${passwordHash}, ${role})
      RETURNING *
    `;
        return mapUser(result[0]);
    }
    static async updateUserPassword(userId, passwordHash) {
        const result = await (0, db_1.default) `
      UPDATE users
      SET password_hash = ${passwordHash}, updated_at = NOW()
      WHERE id = ${userId}
      RETURNING *
    `;
        if (result.length === 0) {
            throw new Error('User not found');
        }
        return mapUser(result[0]);
    }
    static async createGuestSession(sessionId) {
        const result = await (0, db_1.default) `
      INSERT INTO guest_sessions (session_id)
      VALUES (${sessionId})
      RETURNING *
    `;
        return mapGuestSession(result[0]);
    }
    static async findGuestSession(sessionId) {
        const result = await (0, db_1.default) `
      SELECT *
      FROM guest_sessions
      WHERE session_id = ${sessionId}
      LIMIT 1
    `;
        if (result.length === 0)
            return null;
        return mapGuestSession(result[0]);
    }
    static async touchGuestSession(sessionId) {
        const result = await (0, db_1.default) `
      UPDATE guest_sessions
      SET last_activity = NOW(), access_count = access_count + 1
      WHERE session_id = ${sessionId}
      RETURNING *
    `;
        if (result.length === 0) {
            throw new Error('Guest session not found');
        }
        return mapGuestSession(result[0]);
    }
    static async deleteGuestSession(sessionId) {
        await (0, db_1.default) `
      DELETE FROM guest_sessions
      WHERE session_id = ${sessionId}
    `;
    }
}
exports.AuthRepository = AuthRepository;
