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
}
exports.AuthRepository = AuthRepository;
