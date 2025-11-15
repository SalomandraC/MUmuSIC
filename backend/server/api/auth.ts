// server/api/auth.ts
import { Request, Response } from 'express';
import sql from '../config/db';
import bcrypt from 'bcrypt';

declare module 'express-session' {
  interface SessionData {
    userId?: number;
    authenticated?: boolean;
  }
}

export const register = async (req: Request, res: Response) => {
  try {
    const { lastname, firstname, middlename, email, password } = req.body;
    if (!lastname || !firstname || !email || !password) {
      return res.status(400).json({ error: 'Все обязательные поля должны быть заполнены' });
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ error: 'Некорректный формат email' });
    }
    const existingUser = await sql`
      SELECT 1 FROM accounts WHERE email = ${email.toLowerCase().trim()}
    `;

    if (existingUser.length > 0) {
      return res.status(409).json({ error: 'Пользователь с таким email уже существует' });
    }
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);
    const newUser = await sql`
      INSERT INTO accounts 
        (lastname, firstname, middlename, email, password_hash, have_report)
      VALUES 
        (${lastname}, ${firstname}, ${middlename || null}, 
         ${email.toLowerCase().trim()}, ${passwordHash}, false)
      RETURNING 
        pk_accounts_id, lastname, firstname, middlename, email
    `;
    req.session.userId = newUser[0].pk_accounts_id;
    req.session.authenticated = true;

    res.status(201).json(newUser[0]);
  } catch (error) {
    console.error('Ошибка регистрации:', error);
    res.status(500).json({ error: 'Произошла ошибка при регистрации' });
  }
};

export const login = async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Email и пароль обязательны' });
    }
    const users = await sql`
      SELECT * FROM accounts WHERE email = ${email.toLowerCase().trim()}
    `;

    if (users.length === 0) {
      return res.status(401).json({ error: 'Неверные учетные данные' });
    }

    const user = users[0];
    const passwordMatch = await bcrypt.compare(password, user.password_hash);
    if (!passwordMatch) {
      return res.status(401).json({ error: 'Неверные учетные данные' });
    }
    req.session.userId = user.pk_accounts_id;
    req.session.authenticated = true;
    const { password_hash, ...userData } = user;
    res.json(userData);
  } catch (error) {
    console.error('Ошибка входа:', error);
    res.status(500).json({ error: 'Произошла ошибка при входе' });
  }
};

export const logout = async (req: Request, res: Response): Promise<void> => {
  try {
    req.session.destroy((err) => {
      if (err) {
        console.error('Ошибка при выходе:', err);
        res.status(500).json({ error: 'Ошибка при выходе' });
        return;
      }
      res.clearCookie('connect.sid');
      res.json({ message: 'Выход выполнен успешно' });
    });
  } catch (error) {
    console.error('Ошибка при выходе:', error);
    res.status(500).json({ error: 'Произошла ошибка при выходе' });
  }
};

export const checkAuth = async (req: Request, res: Response) => {
  try {
    if (!req.session.authenticated || !req.session.userId) {
      return res.status(401).json({ authenticated: false });
    }

    const users = await sql`
      SELECT pk_accounts_id, lastname, firstname, middlename, email
      FROM accounts WHERE pk_accounts_id = ${req.session.userId}
    `;

    if (users.length === 0) {
      req.session.destroy((err) => {
        if (err) {
          console.error('Ошибка при уничтожении сессии:', err);
        }
        res.status(401).json({ authenticated: false });
      });
      return; 
    }

    res.json({ 
      authenticated: true,
      user: users[0]
    });
  } catch (error) {
    console.error('Ошибка проверки аутентификации:', error);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
};