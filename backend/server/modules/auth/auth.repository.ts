import sql from '../../config/db';
import {
  GuestSessionRecord,
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

const mapGuestSession = (record: any): GuestSessionRecord => ({
  session_id: record.session_id,
  last_activity: record.last_activity,
  access_count: record.access_count,
  created_at: record.created_at,
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

  static async updateUserPassword(userId: number, passwordHash: string): Promise<UserRecord> {
    const result = await sql`
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

  static async createGuestSession(sessionId: string): Promise<GuestSessionRecord> {
    const result = await sql`
      INSERT INTO guest_sessions (session_id)
      VALUES (${sessionId})
      RETURNING *
    `;

    return mapGuestSession(result[0]);
  }

  static async findGuestSession(sessionId: string): Promise<GuestSessionRecord | null> {
    const result = await sql`
      SELECT *
      FROM guest_sessions
      WHERE session_id = ${sessionId}
      LIMIT 1
    `;

    if (result.length === 0) return null;
    return mapGuestSession(result[0]);
  }

  static async touchGuestSession(sessionId: string): Promise<GuestSessionRecord> {
    const result = await sql`
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

  static async deleteGuestSession(sessionId: string): Promise<void> {
    await sql`
      DELETE FROM guest_sessions
      WHERE session_id = ${sessionId}
    `;
  }
}

