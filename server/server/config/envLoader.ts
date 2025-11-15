import fs from 'fs';
import path from 'path';

const envPath = path.resolve(__dirname, '../../.env');
let env: Record<string, string> = {};

if (fs.existsSync(envPath)) {
  const content = fs.readFileSync(envPath, 'utf8');
  const lines = content.split(/\r?\n/);

  lines.forEach(line => {
    const trimmedLine = line.trim();
    if (!trimmedLine || trimmedLine.startsWith('#')) return;

    const [key, ...values] = trimmedLine.split('=');
    const value = values.join('=');

    if (key && value) {
      env[key] = value;
    }
  });
} else {
  console.warn('.env file not found');
}

export default env;