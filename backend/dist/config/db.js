"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const postgres_1 = __importDefault(require("postgres"));
const appConfig_1 = require("./appConfig");
const sql = (0, postgres_1.default)(appConfig_1.appConfig.databaseUrl, {
    ssl: appConfig_1.appConfig.isProduction ? { rejectUnauthorized: false } : undefined,
    max: 10,
    connect_timeout: 30,
});
exports.default = sql;
