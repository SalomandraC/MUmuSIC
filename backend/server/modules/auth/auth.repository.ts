import sql from '../../config/db';
import {
  UserRecord,
  UserRole,
} from './auth.types';

const mapUser = (record: any): UserRecord => ({
  id: record.id,
  username: record.username,
  email: record.email,
  password_hash: record.password_hash,
  role: record.role,
  guest_session_id: record.guest_session_id,
  created_at: record.created_at,
  updated_at: record.updated_at,
});

export class AuthRepository {
  static async findUserByEmail(email: string): Promise<UserRecord | null> {
    const result = await sql`
      SELECT *
      FROM users
      WHERE lower(email) = lower(${email})
      LIMIT 1
    `;

    if (result.length === 0) return null;
    return mapUser(result[0]);
  }

  static async findUserByUsername(username: string): Promise<UserRecord | null> {
    const result = await sql`
      SELECT *
      FROM users
      WHERE lower(username) = lower(${username})
      LIMIT 1
    `;

    if (result.length === 0) return null;
    return mapUser(result[0]);
  }

  static async findUserById(id: number): Promise<UserRecord | null> {
    const result = await sql`
      SELECT *
      FROM users
      WHERE id = ${id}
      LIMIT 1
    `;

    if (result.length === 0) return null;
    return mapUser(result[0]);
  }

  static async createUser(username: string, email: string, passwordHash: string, role: UserRole = 'user'): Promise<UserRecord> {
    const result = await sql`
      INSERT INTO users (username, email, password_hash, role)
      VALUES (${username}, ${email}, ${passwordHash}, ${role})
      RETURNING *
    `;

    return mapUser(result[0]);
  }
}

