"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const envPath = path_1.default.resolve(__dirname, '../../.env');
let env = {};
if (fs_1.default.existsSync(envPath)) {
    const content = fs_1.default.readFileSync(envPath, 'utf8');
    const lines = content.split(/\r?\n/);
    lines.forEach(line => {
        const trimmedLine = line.trim();
        if (!trimmedLine || trimmedLine.startsWith('#'))
            return;
        const [key, ...values] = trimmedLine.split('=');
        const value = values.join('=');
        if (key && value) {
            env[key] = value;
        }
    });
}
else {
    console.warn('.env file not found');
}
exports.default = env;
