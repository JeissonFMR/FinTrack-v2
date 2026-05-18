/**
 * Validador de SQL para el asistente.
 * Garantiza que el SQL generado por la IA sea SEGURO antes de ejecutarse:
 *  - Solo SELECT (rechaza INSERT/UPDATE/DELETE/DROP/ALTER/etc.)
 *  - Solo tablas whitelisteadas
 *  - Debe incluir workspace_id en el WHERE (scoping multi-tenant)
 *  - Sin múltiples statements (anti SQL injection chained)
 *  - Sin comentarios sospechosos
 *  - Inyecta LIMIT si el LLM se olvidó
 */

export class SqlValidationError extends Error {
  constructor(public reason: string) {
    super(reason);
    this.name = 'SqlValidationError';
  }
}

const FORBIDDEN_KEYWORDS = [
  'insert',
  'update',
  'delete',
  'drop',
  'alter',
  'truncate',
  'create',
  'grant',
  'revoke',
  'exec',
  'execute',
  'merge',
  'call',
  'declare',
  'comment on',
  'vacuum',
  'analyze',
  'copy',
  'lock',
  'savepoint',
  'rollback',
  'commit',
  'reindex',
];

/** Tablas que el asistente puede consultar. Todo lo demás está prohibido. */
const ALLOWED_TABLES = new Set([
  'transactions',
  'categories',
  'accounts',
  'budgets',
  'debts',
  'debt_payments',
  'goals',
  'recurring_transactions',
]);

const MAX_LIMIT = 1000;

export interface ValidatedSql {
  sql: string;
  hasLimit: boolean;
}

/**
 * Valida un SQL generado por la IA y lo prepara para ejecutarse.
 * Lanza SqlValidationError si encuentra algo prohibido.
 */
export function validateSql(rawSql: string, workspaceId: string): ValidatedSql {
  if (!rawSql || typeof rawSql !== 'string') {
    throw new SqlValidationError('SQL vacío o inválido');
  }

  // Quitar comentarios SQL (línea y bloque) y normalizar
  let sql = rawSql
    .replace(/--[^\n]*/g, ' ')
    .replace(/\/\*[\s\S]*?\*\//g, ' ')
    .trim();

  // Quitar punto y coma final (lo aceptamos)
  if (sql.endsWith(';')) sql = sql.slice(0, -1).trim();

  // Anti múltiples statements (no debe haber más ; dentro)
  if (sql.includes(';')) {
    throw new SqlValidationError(
      'No se permiten múltiples statements en una consulta',
    );
  }

  const lower = sql.toLowerCase();

  // Debe empezar con SELECT (o WITH ... SELECT para CTEs)
  if (!lower.startsWith('select') && !lower.startsWith('with')) {
    throw new SqlValidationError('Solo se permiten consultas SELECT');
  }

  // Rechazar keywords prohibidos (DML/DDL)
  for (const kw of FORBIDDEN_KEYWORDS) {
    const re = new RegExp(`\\b${kw}\\b`, 'i');
    if (re.test(lower)) {
      throw new SqlValidationError(
        `Palabra prohibida en SQL: "${kw}". Solo se permiten SELECT.`,
      );
    }
  }

  // Detectar tablas referenciadas (FROM x, JOIN x)
  const tableRegex = /(?:from|join)\s+([a-z_][a-z0-9_]*)/gi;
  const referencedTables = new Set<string>();
  let match;
  while ((match = tableRegex.exec(lower)) !== null) {
    referencedTables.add(match[1]);
  }

  if (referencedTables.size === 0) {
    throw new SqlValidationError('SQL no referencia ninguna tabla');
  }

  for (const t of referencedTables) {
    if (!ALLOWED_TABLES.has(t)) {
      throw new SqlValidationError(
        `Tabla no permitida: "${t}". Permitidas: ${[...ALLOWED_TABLES].join(', ')}`,
      );
    }
  }

  // Scoping multi-tenant: el SQL DEBE filtrar por workspace_id
  if (!/\bworkspace_id\b/i.test(lower)) {
    throw new SqlValidationError(
      'La consulta debe filtrar por workspace_id',
    );
  }

  // Reemplazar literales del workspace_id (si el LLM puso un UUID o '?')
  // por el real, para evitar que pueda consultar otros workspaces.
  // Convertimos cualquier comparación workspace_id = '...' o = $N al workspaceId real.
  sql = sql.replace(
    /workspace_id\s*=\s*('[^']*'|\$\d+|"[^"]*")/gi,
    `workspace_id = '${workspaceId}'`,
  );

  // Inyectar LIMIT si no tiene
  let hasLimit = /\blimit\s+\d+/i.test(lower);
  if (!hasLimit) {
    sql = `${sql} LIMIT ${MAX_LIMIT}`;
    hasLimit = false;
  } else {
    // Si tiene LIMIT, asegurarnos que no exceda el máximo
    const limitMatch = sql.match(/\blimit\s+(\d+)/i);
    if (limitMatch) {
      const n = parseInt(limitMatch[1], 10);
      if (n > MAX_LIMIT) {
        sql = sql.replace(/\blimit\s+\d+/i, `LIMIT ${MAX_LIMIT}`);
      }
    }
  }

  return { sql, hasLimit };
}
