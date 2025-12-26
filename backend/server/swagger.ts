import swaggerJsdoc from 'swagger-jsdoc';
import { SwaggerDefinition } from 'swagger-jsdoc';

const swaggerDefinition: SwaggerDefinition = {
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
      url: 'http://localhost:5050',
      description: 'Development server',
    },
  ],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description: 'JWT access token',
      },
    },
    schemas: {
      Track: {
        type: 'object',
        properties: {
          id: { type: 'integer' },
          user_id: { type: 'integer' },
          title: { type: 'string' },
          artist: { type: 'string' },
          album: { type: 'string' },
          duration: { type: 'integer', description: 'seconds' },
          file_path: { type: 'string' },
          file_format: { type: 'string', example: 'mp3' },
          file_size: { type: 'integer' },
          notes: { type: 'string' },
          is_public: { type: 'boolean' },
          created_at: { type: 'string', format: 'date-time' },
        },
      },
      User: {
        type: 'object',
        properties: {
          id: { type: 'integer', description: 'ID пользователя' },
          username: { type: 'string', description: 'Username' },
          email: { type: 'string', format: 'email', description: 'Email' },
          role: { type: 'string', description: 'Роль пользователя' },
          guestSessionId: { type: 'string', nullable: true },
          createdAt: { type: 'string', format: 'date-time' },
          updatedAt: { type: 'string', format: 'date-time' },
        },
      },
      AuthTokens: {
        type: 'object',
        properties: {
          accessToken: { type: 'string' },
          refreshToken: { type: 'string' },
        },
      },
      RegisterRequest: {
        type: 'object',
        required: ['username', 'email', 'password'],
        properties: {
          username: { type: 'string', example: 'musicfan' },
          email: { type: 'string', format: 'email', example: 'user@example.com' },
          password: { type: 'string', format: 'password', minLength: 8 },
        },
      },
      LoginRequest: {
        type: 'object',
        required: ['email', 'password'],
        properties: {
          email: { type: 'string', format: 'email' },
          password: { type: 'string', format: 'password' },
        },
      },
      RefreshTokenRequest: {
        type: 'object',
        required: ['refreshToken'],
        properties: {
          refreshToken: { type: 'string' },
        },
      },
      Error: {
        type: 'object',
        properties: {
          error: { type: 'string', description: 'Сообщение об ошибке' },
        },
      },
      AuthResponse: {
        type: 'object',
        properties: {
          user: { $ref: '#/components/schemas/User' },
          tokens: { $ref: '#/components/schemas/AuthTokens' },
        },
      },
      PlaylistTrack: {
        type: 'object',
        properties: {
          trackId: { type: 'integer', description: 'ID трека из iTunes' },
          trackName: { type: 'string', description: 'Название трека' },
          artistName: { type: 'string', description: 'Исполнитель' },
          trackTimeMillis: { type: 'integer', description: 'Длительность в миллисекундах' },
          artworkUrl100: { type: 'string', description: 'URL обложки' },
          previewUrl: { type: 'string', description: 'URL превью трека' },
          position: { type: 'integer', description: 'Позиция в плейлисте' },
        },
        required: ['trackId', 'position'],
      },
      UserPlaylist: {
        type: 'object',
        properties: {
          id: { type: 'integer', description: 'ID плейлиста (используется при синхронизации)' },
          name: { type: 'string', description: 'Название плейлиста' },
          description: { type: 'string', description: 'Описание плейлиста' },
          coverImageUri: { type: 'string', description: 'URI обложки плейлиста' },
          tracks: {
            type: 'array',
            items: { $ref: '#/components/schemas/PlaylistTrack' },
            description: 'Список треков в плейлисте',
          },
          createdAt: { type: 'string', format: 'date-time', description: 'Дата создания' },
          updatedAt: { type: 'string', format: 'date-time', description: 'Дата обновления' },
        },
        required: ['id', 'name', 'tracks'],
      },
      SyncData: {
        type: 'object',
        properties: {
          playlists: {
            type: 'array',
            items: { $ref: '#/components/schemas/UserPlaylist' },
            description: 'Список плейлистов пользователя',
          },
        },
        required: ['playlists'],
      },
      TrackResponse: {
        type: 'object',
        properties: {
          id: { type: 'integer', description: 'ID трека' },
          title: { type: 'string', description: 'Название трека' },
          artist: { type: 'string', description: 'Исполнитель' },
          album: { type: 'string', description: 'Альбом' },
          duration: { type: 'integer', description: 'Длительность в секундах' },
          file_path: { type: 'string', description: 'Относительный путь к файлу на сервере' },
          file_url: { type: 'string', description: 'URL для доступа к файлу' },
          file_format: { type: 'string', description: 'Формат файла (mp3, wav и т.д.)' },
          file_size: { type: 'integer', description: 'Размер файла в байтах' },
          notes: { type: 'string', description: 'Заметки' },
          is_public: { type: 'boolean', description: 'Публичный доступ' },
          created_at: { type: 'string', format: 'date-time', description: 'Дата создания' },
        },
        required: ['id', 'title', 'file_path', 'file_url', 'file_format', 'is_public', 'created_at'],
      },
    },
  },
};

const options = {
  definition: swaggerDefinition,
  apis: [
    './server/**/*.ts'
  ],
};

export const swaggerSpec = swaggerJsdoc(options);

