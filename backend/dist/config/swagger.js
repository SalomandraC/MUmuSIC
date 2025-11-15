"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.swaggerSpec = void 0;
const swagger_jsdoc_1 = __importDefault(require("swagger-jsdoc"));
const swaggerDefinition = {
    openapi: '3.0.0',
    info: {
        title: 'Study Practice API',
        version: '1.0.0',
        description: 'API для системы обучения и практики',
        contact: {
            name: 'API Support',
        },
    },
    servers: [
        {
            url: 'http://localhost:5000',
            description: 'Development server',
        },
    ],
    components: {
        securitySchemes: {
            sessionAuth: {
                type: 'apiKey',
                in: 'cookie',
                name: 'connect.sid',
                description: 'Session-based authentication',
            },
        },
        schemas: {
            User: {
                type: 'object',
                properties: {
                    pk_accounts_id: {
                        type: 'integer',
                        description: 'ID пользователя',
                    },
                    lastname: {
                        type: 'string',
                        description: 'Фамилия',
                    },
                    firstname: {
                        type: 'string',
                        description: 'Имя',
                    },
                    middlename: {
                        type: 'string',
                        nullable: true,
                        description: 'Отчество',
                    },
                    email: {
                        type: 'string',
                        format: 'email',
                        description: 'Email адрес',
                    },
                    have_report: {
                        type: 'boolean',
                        description: 'Наличие отчета',
                    },
                },
            },
            RegisterRequest: {
                type: 'object',
                required: ['lastname', 'firstname', 'email', 'password'],
                properties: {
                    lastname: {
                        type: 'string',
                        description: 'Фамилия',
                        example: 'Иванов',
                    },
                    firstname: {
                        type: 'string',
                        description: 'Имя',
                        example: 'Иван',
                    },
                    middlename: {
                        type: 'string',
                        nullable: true,
                        description: 'Отчество',
                        example: 'Иванович',
                    },
                    email: {
                        type: 'string',
                        format: 'email',
                        description: 'Email адрес',
                        example: 'ivan@example.com',
                    },
                    password: {
                        type: 'string',
                        format: 'password',
                        description: 'Пароль',
                        minLength: 6,
                        example: 'password123',
                    },
                },
            },
            LoginRequest: {
                type: 'object',
                required: ['email', 'password'],
                properties: {
                    email: {
                        type: 'string',
                        format: 'email',
                        description: 'Email адрес',
                        example: 'ivan@example.com',
                    },
                    password: {
                        type: 'string',
                        format: 'password',
                        description: 'Пароль',
                        example: 'password123',
                    },
                },
            },
            Error: {
                type: 'object',
                properties: {
                    error: {
                        type: 'string',
                        description: 'Сообщение об ошибке',
                    },
                },
            },
            AuthResponse: {
                type: 'object',
                properties: {
                    authenticated: {
                        type: 'boolean',
                        description: 'Статус аутентификации',
                    },
                    user: {
                        $ref: '#/components/schemas/User',
                    },
                },
            },
        },
    },
};
const options = {
    definition: swaggerDefinition,
    apis: [
        './server/**/*.ts',
        './dist/**/*.js'
    ],
};
exports.swaggerSpec = (0, swagger_jsdoc_1.default)(options);
