import crypto from 'crypto';
import sql from '../../config/db';

type Sql = typeof sql;

export interface RefreshTokenRecord {
  id: number;
  user_id: number;
  expires_at: Date;
  revoked_at: Date | null;
}

export const hashToken = (token: string) =>
  crypto.createHash('sha256').update(token).digest('hex');

export class RefreshTokenRepository {
  static async create(
    userId: number,
    token: string,
    expiresAt: Date,
    device: string | null,
    db: Sql = sql
  ): Promise<number> {
    const [row] = await db`
      INSERT INTO refresh_tokens (user_id, token_hash, device, expires_at)
      VALUES (${userId}, ${hashToken(token)}, ${device}, ${expiresAt})
      RETURNING id
    `;
    return Number(row.id);
  }

  static async findByToken(token: string, db: Sql = sql): Promise<RefreshTokenRecord | null> {
    const rows = await db`
      SELECT id, user_id, expires_at, revoked_at
      FROM refresh_tokens
      WHERE token_hash = ${hashToken(token)}
      LIMIT 1
    `;
    if (rows.length === 0) return null;
    const row = rows[0];
    return {
      id: Number(row.id),
      user_id: row.user_id,
      expires_at: row.expires_at,
      revoked_at: row.revoked_at,
    };
  }

  /**
   * Атомарно отзывает активный токен. Возвращает false, если токен уже отозван:
   * так два параллельных refresh с одним токеном не получат две новые пары.
   */
  static async revokeIfActive(id: number, db: Sql = sql): Promise<boolean> {
    const rows = await db`
      UPDATE refresh_tokens
      SET revoked_at = now()
      WHERE id = ${id} AND revoked_at IS NULL
      RETURNING id
    `;
    return rows.length > 0;
  }

  static async setReplacedBy(id: number, replacedBy: number, db: Sql = sql): Promise<void> {
    await db`UPDATE refresh_tokens SET replaced_by = ${replacedBy} WHERE id = ${id}`;
  }

  static async revokeAllForUser(userId: number, db: Sql = sql): Promise<number> {
    const rows = await db`
      UPDATE refresh_tokens
      SET revoked_at = now()
      WHERE user_id = ${userId} AND revoked_at IS NULL
      RETURNING id
    `;
    return rows.length;
  }

  static async deleteExpired(db: Sql = sql): Promise<number> {
    const rows = await db`
      DELETE FROM refresh_tokens
      WHERE expires_at < now() - interval '1 day'
      RETURNING id
    `;
    return rows.length;
  }
}
