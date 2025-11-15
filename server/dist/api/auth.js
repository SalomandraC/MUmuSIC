"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.checkAuth = exports.logout = exports.login = exports.register = void 0;
const db_1 = __importDefault(require("../config/db"));
const bcrypt_1 = __importDefault(require("bcrypt"));
const register = async (req, res) => {
    try {
        const { lastname, firstname, middlename, email, password } = req.body;
        if (!lastname || !firstname || !email || !password) {
            return res.status(400).json({ error: 'Все обязательные поля должны быть заполнены' });
        }
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
            return res.status(400).json({ error: 'Некорректный формат email' });
        }
        const existingUser = await (0, db_1.default) `
      SELECT 1 FROM accounts WHERE email = ${email.toLowerCase().trim()}
    `;
        if (existingUser.length > 0) {
            return res.status(409).json({ error: 'Пользователь с таким email уже существует' });
        }
        const saltRounds = 10;
        const passwordHash = await bcrypt_1.default.hash(password, saltRounds);
        const newUser = await (0, db_1.default) `
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
    }
    catch (error) {
        console.error('Ошибка регистрации:', error);
        res.status(500).json({ error: 'Произошла ошибка при регистрации' });
    }
};
exports.register = register;
const login = async (req, res) => {
    try {
        const { email, password } = req.body;
        if (!email || !password) {
            return res.status(400).json({ error: 'Email и пароль обязательны' });
        }
        const users = await (0, db_1.default) `
      SELECT * FROM accounts WHERE email = ${email.toLowerCase().trim()}
    `;
        if (users.length === 0) {
            return res.status(401).json({ error: 'Неверные учетные данные' });
        }
        const user = users[0];
        const passwordMatch = await bcrypt_1.default.compare(password, user.password_hash);
        if (!passwordMatch) {
            return res.status(401).json({ error: 'Неверные учетные данные' });
        }
        req.session.userId = user.pk_accounts_id;
        req.session.authenticated = true;
        const { password_hash, ...userData } = user;
        res.json(userData);
    }
    catch (error) {
        console.error('Ошибка входа:', error);
        res.status(500).json({ error: 'Произошла ошибка при входе' });
    }
};
exports.login = login;
const logout = async (req, res) => {
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
    }
    catch (error) {
        console.error('Ошибка при выходе:', error);
        res.status(500).json({ error: 'Произошла ошибка при выходе' });
    }
};
exports.logout = logout;
const checkAuth = async (req, res) => {
    try {
        if (!req.session.authenticated || !req.session.userId) {
            return res.status(401).json({ authenticated: false });
        }
        const users = await (0, db_1.default) `
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
    }
    catch (error) {
        console.error('Ошибка проверки аутентификации:', error);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
};
exports.checkAuth = checkAuth;
