import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Groq from 'groq-sdk';
import { PrismaService } from '../prisma/prisma.service';
import { SqlValidationError, validateSql } from './sql-validator';

const SCHEMA_DESCRIPTION = `
ESQUEMA DE BASE DE DATOS (PostgreSQL):

Tabla: transactions
  - id (uuid)
  - workspace_id (uuid)            ← SIEMPRE filtra por este
  - account_id (uuid)              ← FK a accounts.id
  - category_id (uuid, nullable)   ← FK a categories.id
  - type (text: 'INCOME', 'EXPENSE', 'TRANSFER')
  - amount (decimal)
  - description (text)
  - date (timestamp)
  - notes (text, nullable)
  - transfer_to_account_id (uuid, nullable)
  - recurring_id (uuid, nullable)
  - created_at, updated_at

Tabla: categories
  - id (uuid)
  - workspace_id (uuid)
  - name (text)
  - type (text: 'INCOME', 'EXPENSE', 'BOTH')
  - color (text), icon (text)
  - parent_id (uuid, nullable, jerarquía)

Tabla: accounts
  - id (uuid)
  - workspace_id (uuid)
  - name (text)
  - type (text: 'CASH', 'BANK', 'CREDIT_CARD', 'DIGITAL_WALLET', 'INVESTMENT', 'SAVINGS', 'LOAN')
  - balance (decimal)
  - currency (text)
  - card_last4 (text, nullable)
  - is_active (boolean)

Tabla: budgets
  - id (uuid)
  - workspace_id (uuid)
  - category_id (uuid)
  - amount (decimal)
  - period (text: 'WEEKLY', 'MONTHLY', 'YEARLY')
  - start_date (timestamp)
  - alert_at (int)

Tabla: debts
  - id (uuid)
  - workspace_id (uuid)
  - name (text)
  - type (text: 'OWED_BY_ME', 'OWED_TO_ME')
  - total_amount (decimal)
  - paid_amount (decimal)
  - due_date (timestamp, nullable)
  - is_paid (boolean)

Tabla: debt_payments
  - id (uuid)
  - debt_id (uuid)
  - amount (decimal)
  - paid_at (timestamp)

Tabla: goals
  - id (uuid)
  - workspace_id (uuid)
  - name (text)
  - target_amount (decimal)
  - current_amount (decimal)
  - deadline (timestamp, nullable)
  - status (text: 'IN_PROGRESS', 'COMPLETED')

Tabla: recurring_transactions
  - id (uuid)
  - workspace_id (uuid)
  - name (text)
  - type, amount, account_id, category_id
  - frequency (text: 'DAILY', 'WEEKLY', 'BIWEEKLY', 'MONTHLY', 'YEARLY')
  - next_due_date (timestamp)
  - is_active (boolean)

CONVENCIONES:
- Los campos monetarios son DECIMAL (tratarlos como números).
- Las fechas son timestamps. Para comparar usa: date >= '2026-05-01'
- Para texto usa ILIKE para case-insensitive: description ILIKE '%rappi%'
- Joins comunes:
  - transactions JOIN categories ON transactions.category_id = categories.id
  - transactions JOIN accounts ON transactions.account_id = accounts.id
  - budgets JOIN categories ON budgets.category_id = categories.id
`;

const SQL_SYSTEM_PROMPT = `Eres un experto en PostgreSQL que ayuda a un usuario a consultar sus finanzas personales.

${SCHEMA_DESCRIPTION}

REGLAS OBLIGATORIAS:
1. Solo genera consultas SELECT. NUNCA INSERT, UPDATE, DELETE, DROP, ALTER, etc.
2. SIEMPRE incluye "WHERE workspace_id = '{{WORKSPACE_ID}}'" para filtrar al usuario.
3. Si haces JOIN, incluye también el workspace_id en las otras tablas para seguridad.
4. Usa siempre alias claros y agrupa cuando sea apropiado (SUM, COUNT, AVG).
5. Para fechas relativas (este mes, año pasado, etc.) usa la fecha de hoy: {{TODAY}}.
6. Limita resultados a 100 filas máximo a menos que sea una agregación.
7. Para búsquedas de texto usa ILIKE (case insensitive).
8. NO escribas markdown ni explicaciones, SOLO devuelve el SQL puro.

Ejemplos:

Pregunta: "¿Cuánto gasté en RAPPI este año?"
SQL: SELECT SUM(amount) AS total, COUNT(*) AS veces FROM transactions WHERE workspace_id = '{{WORKSPACE_ID}}' AND type = 'EXPENSE' AND description ILIKE '%rappi%' AND date >= '{{YEAR_START}}'

Pregunta: "Mis 5 cuentas con más saldo"
SQL: SELECT name, balance, type FROM accounts WHERE workspace_id = '{{WORKSPACE_ID}}' AND is_active = true ORDER BY balance DESC LIMIT 5

Pregunta: "Top categorías de gasto este mes"
SQL: SELECT c.name, SUM(t.amount) AS total, COUNT(*) AS movimientos FROM transactions t JOIN categories c ON t.category_id = c.id WHERE t.workspace_id = '{{WORKSPACE_ID}}' AND t.type = 'EXPENSE' AND t.date >= '{{MONTH_START}}' GROUP BY c.name ORDER BY total DESC LIMIT 10`;

const RESPONSE_SYSTEM_PROMPT = `Eres un asistente financiero personal.
Recibes una pregunta del usuario y los resultados de una consulta a sus datos financieros.
Tu trabajo es responder en español, de forma clara, breve y útil.

REGLAS:
- Responde 1-3 párrafos máximo, sin markdown excesivo.
- Formatea montos con separadores: $1.234.567 (puntos como miles).
- Si los resultados están vacíos, dilo amablemente.
- Da contexto cuando sea útil: comparativas, porcentajes, observaciones.
- No inventes datos que no estén en los resultados.`;

@Injectable()
export class AssistantService {
  private readonly logger = new Logger(AssistantService.name);
  private readonly client: Groq;
  private readonly sqlModel: string;
  private readonly responseModel: string;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    const apiKey = this.config.get<string>('GROQ_API_KEY');
    this.client = new Groq({ apiKey: apiKey ?? '' });
    // Modelo más potente para generar SQL correctamente
    this.sqlModel =
      this.config.get<string>('LLM_MODEL_SQL') ?? 'llama-3.3-70b-versatile';
    // Modelo rápido para formular respuesta natural
    this.responseModel =
      this.config.get<string>('LLM_MODEL') ?? 'llama-3.1-8b-instant';
  }

  async ask(workspaceId: string, question: string): Promise<AssistantResponse> {
    if (!question || question.trim().length === 0) {
      return { answer: 'Hazme una pregunta sobre tus finanzas.', error: false };
    }

    // 1. Pedir SQL al LLM
    let sql: string;
    try {
      sql = await this.generateSql(workspaceId, question);
    } catch (err) {
      this.logger.error(`Error generando SQL: ${(err as Error).message}`);
      return {
        answer:
          'Tuve problemas para entender tu pregunta. ¿Puedes reformularla?',
        error: true,
      };
    }

    this.logger.log(`SQL generado: ${sql}`);

    // 2. Validar el SQL
    let validated;
    try {
      validated = validateSql(sql, workspaceId);
    } catch (err) {
      const reason = err instanceof SqlValidationError ? err.reason : 'desconocido';
      this.logger.warn(`SQL rechazado: ${reason}`);
      return {
        answer:
          'No puedo realizar esa consulta por seguridad. ¿Puedes pedirla de otra forma?',
        error: true,
        debug: { sql, reason },
      };
    }

    // 3. Ejecutar la consulta con timeout
    let rows: unknown[];
    try {
      rows = await this.executeWithTimeout(validated.sql, 5000);
    } catch (err) {
      this.logger.error(`Error ejecutando SQL: ${(err as Error).message}`);
      return {
        answer:
          'Hubo un problema consultando tus datos. Intenta de nuevo o reformula la pregunta.',
        error: true,
        debug: { sql: validated.sql },
      };
    }

    // 4. Pedir al LLM que formule la respuesta natural
    const answer = await this.formulateResponse(question, rows);

    return {
      answer,
      error: false,
      debug: { sql: validated.sql, rowCount: rows.length },
    };
  }

  private async generateSql(workspaceId: string, question: string): Promise<string> {
    const today = new Date();
    const yearStart = `${today.getFullYear()}-01-01`;
    const monthStart = `${today.getFullYear()}-${String(today.getMonth() + 1).padStart(2, '0')}-01`;

    const systemPrompt = SQL_SYSTEM_PROMPT
      .replaceAll('{{WORKSPACE_ID}}', workspaceId)
      .replaceAll('{{TODAY}}', today.toISOString().split('T')[0])
      .replaceAll('{{YEAR_START}}', yearStart)
      .replaceAll('{{MONTH_START}}', monthStart);

    const completion = await this.client.chat.completions.create({
      model: this.sqlModel,
      temperature: 0,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: question },
      ],
    });

    const raw = completion.choices[0]?.message?.content ?? '';
    // El LLM a veces envuelve en ```sql ... ``` — limpiarlo
    return raw
      .replace(/```sql\s*/gi, '')
      .replace(/```/g, '')
      .trim();
  }

  private async executeWithTimeout(sql: string, ms: number): Promise<unknown[]> {
    const queryPromise = this.prisma.$queryRawUnsafe<unknown[]>(sql);
    const timeoutPromise = new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error('Query timeout')), ms),
    );
    return Promise.race([queryPromise, timeoutPromise]);
  }

  private async formulateResponse(
    question: string,
    rows: unknown[],
  ): Promise<string> {
    const dataStr =
      rows.length === 0
        ? '(consulta sin resultados)'
        : JSON.stringify(rows, decimalReplacer, 2).substring(0, 4000);

    const completion = await this.client.chat.completions.create({
      model: this.responseModel,
      temperature: 0.3,
      messages: [
        { role: 'system', content: RESPONSE_SYSTEM_PROMPT },
        {
          role: 'user',
          content: `Pregunta: ${question}\n\nResultados de la consulta:\n${dataStr}\n\nResponde de forma clara y breve.`,
        },
      ],
    });

    return (
      completion.choices[0]?.message?.content?.trim() ??
      'No tengo respuesta para eso.'
    );
  }
}

/** Prisma devuelve Decimal como objetos; los convertimos a number para el LLM. */
function decimalReplacer(_key: string, value: unknown) {
  if (
    value !== null &&
    typeof value === 'object' &&
    'toString' in value &&
    value.constructor.name === 'Decimal'
  ) {
    return Number((value as { toString(): string }).toString());
  }
  if (typeof value === 'bigint') return Number(value);
  return value;
}

export interface AssistantResponse {
  answer: string;
  error: boolean;
  debug?: {
    sql?: string;
    reason?: string;
    rowCount?: number;
  };
}
