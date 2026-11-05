import crypto from 'crypto';
import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';
import postgres from 'postgres';

dotenv.config();

/**
 * Простой раннер SQL-миграций без сторонних инструментов.
 *
 * Миграции — файлы backend/migrations/NNNN_name.sql, применяются по порядку
 * номеров, каждая в своей транзакции. Применённые записываются в таблицу
 * schema_migrations вместе с контрольной суммой: если уже применённый файл
 * потом изменили, раннер остановится, а не применит схему молча.
 *
 * Команды:
 *   up                — применить все новые миграции
 *   status            — показать, что применено, а что нет
 *   baseline <NNNN>   — отметить миграции до NNNN включительно как применённые,
 *                       не выполняя их (для базы, созданной до миграций)
 *   new <name>        — создать пустой файл следующей миграции
 */

// Работает и из server/db (ts-node), и из dist/db (node)
const MIGRATIONS_DIR = path.resolve(__dirname, '..', '..', 'migrations');
const FILE_PATTERN = /^(\d{4})_([a-z0-9_]+)\.sql$/;
// Произвольный ключ, чтобы два процесса не мигрировали одновременно
const LOCK_KEY = 4_203_117;

interface MigrationFile {
  version: string;
  name: string;
  file: string;
  sql: string;
  checksum: string;
}

function readMigrations(): MigrationFile[] {
  if (!fs.existsSync(MIGRATIONS_DIR)) return [];
  const files = fs
    .readdirSync(MIGRATIONS_DIR)
    .filter((file) => FILE_PATTERN.test(file))
    .sort();

  const seen = new Set<string>();
  return files.map((file) => {
    const [, version, name] = file.match(FILE_PATTERN)!;
    if (seen.has(version)) {
      throw new Error(`Два файла миграции с номером ${version}`);
    }
    seen.add(version);
    // Контрольная сумма не зависит от CRLF/LF, чтобы Windows и Linux совпадали
    const sql = fs.readFileSync(path.join(MIGRATIONS_DIR, file), 'utf8');
    const checksum = crypto
      .createHash('sha256')
      .update(sql.replace(/\r\n/g, '\n'))
      .digest('hex');
    return { version, name, file, sql, checksum };
  });
}

function connect() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL не задан (проверьте backend/.env)');
  // Как в config/db.ts: DATABASE_SSL=require|disable, по умолчанию SSL только в production.
  // appConfig здесь не импортируется, чтобы миграциям не требовались JWT-секреты
  const sslMode = process.env.DATABASE_SSL ?? (process.env.NODE_ENV === 'production' ? 'require' : 'disable');
  return postgres(url, {
    ssl: sslMode === 'require' ? { rejectUnauthorized: false } : undefined,
    max: 1,
    onnotice: () => {},
  });
}

type Sql = ReturnType<typeof connect>;

async function ensureTable(sql: Sql) {
  await sql`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      version    text PRIMARY KEY,
      name       text NOT NULL,
      checksum   text NOT NULL,
      applied_at timestamptz NOT NULL DEFAULT now()
    )
  `;
}

async function appliedMap(sql: Sql) {
  const rows = await sql<{ version: string; checksum: string; applied_at: Date }[]>`
    SELECT version, checksum, applied_at FROM schema_migrations ORDER BY version
  `;
  return new Map(rows.map((r) => [r.version, r]));
}

function checkChecksums(files: MigrationFile[], applied: Map<string, { checksum: string }>) {
  for (const m of files) {
    const row = applied.get(m.version);
    if (row && row.checksum !== m.checksum) {
      throw new Error(
        `Миграция ${m.file} уже применена, но файл изменён. ` +
          'Не меняйте применённые миграции — создайте новую.',
      );
    }
  }
}

async function up(sql: Sql) {
  const files = readMigrations();
  const applied = await appliedMap(sql);
  checkChecksums(files, applied);

  const pending = files.filter((m) => !applied.has(m.version));
  if (pending.length === 0) {
    console.log('Новых миграций нет, схема актуальна.');
    return;
  }

  for (const m of pending) {
    process.stdout.write(`→ ${m.file} ... `);
    await sql.begin(async (tx) => {
      await tx.unsafe(m.sql);
      await tx`
        INSERT INTO schema_migrations (version, name, checksum)
        VALUES (${m.version}, ${m.name}, ${m.checksum})
      `;
    });
    console.log('ok');
  }
  console.log(`Применено миграций: ${pending.length}.`);
}

async function status(sql: Sql) {
  const files = readMigrations();
  const applied = await appliedMap(sql);
  for (const m of files) {
    const row = applied.get(m.version);
    const mark = !row
      ? 'ожидает   '
      : row.checksum === m.checksum
        ? 'применена '
        : 'ИЗМЕНЕНА  ';
    const when = row ? row.applied_at.toISOString() : '';
    console.log(`${mark} ${m.file} ${when}`);
  }
  for (const version of applied.keys()) {
    if (!files.some((m) => m.version === version)) {
      console.log(`нет файла  ${version} (есть в schema_migrations, файла нет)`);
    }
  }
}

async function baseline(sql: Sql, target: string | undefined) {
  if (!target || !/^\d{4}$/.test(target)) {
    throw new Error('Укажите номер: npm run migrate:baseline -- 0001');
  }
  const files = readMigrations().filter((m) => m.version <= target);
  if (files.length === 0) throw new Error(`Нет миграций до ${target}`);
  const applied = await appliedMap(sql);
  for (const m of files) {
    if (applied.has(m.version)) continue;
    await sql`
      INSERT INTO schema_migrations (version, name, checksum)
      VALUES (${m.version}, ${m.name}, ${m.checksum})
    `;
    console.log(`отмечена как применённая: ${m.file}`);
  }
}

function createNew(name: string | undefined) {
  const slug = (name ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
  if (!slug) throw new Error('Укажите имя: npm run migrate:new -- add_track_mood');
  const files = readMigrations();
  const last = files.length ? Number(files[files.length - 1].version) : 0;
  const version = String(last + 1).padStart(4, '0');
  const file = path.join(MIGRATIONS_DIR, `${version}_${slug}.sql`);
  fs.mkdirSync(MIGRATIONS_DIR, { recursive: true });
  fs.writeFileSync(file, `-- ${version}: ${slug}\n\n`);
  console.log(`Создан ${path.relative(process.cwd(), file)}`);
}

async function main() {
  const [command = 'up', arg] = process.argv.slice(2);

  if (command === 'new') {
    createNew(arg);
    return;
  }

  const sql = connect();
  try {
    await sql`SELECT pg_advisory_lock(${LOCK_KEY})`;
    try {
      await ensureTable(sql);
      if (command === 'up') await up(sql);
      else if (command === 'status') await status(sql);
      else if (command === 'baseline') await baseline(sql, arg);
      else throw new Error(`Неизвестная команда: ${command} (up | status | baseline | new)`);
    } finally {
      await sql`SELECT pg_advisory_unlock(${LOCK_KEY})`;
    }
  } finally {
    await sql.end();
  }
}

main().catch((error) => {
  console.error(`Ошибка миграции: ${error instanceof Error ? error.message : error}`);
  process.exit(1);
});
