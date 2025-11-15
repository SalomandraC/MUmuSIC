"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createHttpError = exports.HttpError = void 0;
class HttpError extends Error {
    constructor(statusCode, message) {
        super(message);
        this.statusCode = statusCode;
        Object.setPrototypeOf(this, HttpError.prototype);
    }
}
exports.HttpError = HttpError;
const createHttpError = (statusCode, message) => new HttpError(statusCode, message);
exports.createHttpError = createHttpError;
