import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Groq from 'groq-sdk';

export interface ParsedNotification {
  isTransaction: boolean;
  type?: 'INCOME' | 'EXPENSE' | 'TRANSFER';
  amount?: number;
  merchant?: string;
  bank?: string;
  date?: string; // YYYY-MM-DD
  cardLast4?: string;
  description?: string;
  categoryId?: string | null;
  accountId?: string | null;
  confidence?: number;
  reason?: string;
}

export interface CategoryHint {
  id: string;
  name: string;
  type: 'INCOME' | 'EXPENSE' | 'BOTH';
}

export interface AccountHint {
  id: string;
  name: string;
  cardLast4?: string | null;
}

function buildSystemPrompt(categories: CategoryHint[], accounts: AccountHint[]): string {
  const catSection =
    categories.length === 0
      ? 'El usuario no tiene categorías registradas. Devuelve categoryId: null.'
      : `CATEGORÍAS DISPONIBLES DEL USUARIO:
${categories.map((c) => `- id="${c.id}" → "${c.name}" (tipo=${c.type})`).join('\n')}

REGLAS PARA categoryId (OBLIGATORIO INTENTAR):
Debes copiar EXACTAMENTE uno de los ids listados arriba (entre comillas). NO inventes ids.

MAPEO DE COMERCIOS → NOMBRE DE CATEGORÍA (busca esa categoría en la lista):
- RAPPI, UBER EATS, DOMICILIOS, restaurantes, McDonald's, KFC, Crepes & Waffles, panaderías, cafés, Domino's → "Alimentación"
- UBER, DIDI, CABIFY, taxis, gasolina, ESSO, TERPEL, MIO, TRANSMILENIO, peajes → "Transporte"
- arriendo, administración, gas, agua, luz, EPM, CODENSA, internet, claro, movistar → "Vivienda" o "Servicios" (usa Vivienda para arriendo/admin, Servicios para utilities)
- EPS, droguerías, farmacias, médicos, hospitales, gimnasio, Cruz Verde, Cafam → "Salud"
- NETFLIX, SPOTIFY, HBO, DISNEY+, cine, conciertos, juegos, PlayStation → "Entretenimiento"
- universidades, colegios, cursos, libros, Coursera, Platzi → "Educación"
- ZARA, H&M, FALABELLA, ropa, zapatos → "Ropa"
- EXITO, JUMBO, D1, ARA, OLÍMPICA, mercado, supermercado, CARULLA → "Alimentación" (sí, mercado va a Alimentación si no hay categoría "Mercado")
- Si nada encaja claramente → busca "Otros gastos" en la lista (para EXPENSE) u "Otros ingresos" (para INCOME)
- Salario, sueldo, pago de nómina → "Salario"
- Freelance, consultoría → "Freelance"

IMPORTANTE:
- Tu objetivo es SIEMPRE devolver un categoryId válido si es transacción. Solo devuelve null si la lista no tiene ninguna categoría razonablemente cercana.
- categoryId DEBE coincidir con uno de los ids listados arriba (cópialo literalmente, incluyendo guiones).
- Solo elige categorías del tipo correcto: si type=EXPENSE solo categorías EXPENSE o BOTH; si type=INCOME solo categorías INCOME o BOTH.`;

  const accountSection =
    accounts.length === 0
      ? 'El usuario no tiene cuentas registradas. Devuelve accountId: null.'
      : `CUENTAS DEL USUARIO:
${accounts.map((a) => `- id="${a.id}" → "${a.name}"${a.cardLast4 ? ` (tarjeta termina en ${a.cardLast4})` : ''}`).join('\n')}

REGLAS PARA accountId:
- Si el SMS/notificación menciona tarjeta terminada en XXXX y alguna cuenta tiene cardLast4 = XXXX → usa ese accountId.
- Si solo hay una cuenta razonable (por banco o única) → úsala.
- Si no puedes determinar la cuenta con certeza → devuelve accountId: null.
- accountId DEBE coincidir EXACTAMENTE con uno de los ids listados (cópialo literal).`;

  return `Eres un parser experto de notificaciones bancarias en español (Colombia).
Analizas el título y contenido de una notificación push y determinas si representa una transacción financiera real.

REGLAS:
- Solo cuenta como transacción: compras, pagos, transferencias enviadas/recibidas, retiros, depósitos.
- NO cuentan: OTPs, códigos de verificación, promociones, notificaciones de seguridad, recordatorios, saldos consultados.
- type=EXPENSE: pagos, compras, retiros, transferencias enviadas.
- type=INCOME: depósitos, transferencias recibidas, abonos.
- type=TRANSFER: movimientos entre cuentas propias del mismo banco.
- amount: extrae el monto numérico (sin signo, sin separadores de miles, decimales con punto).
- merchant: nombre del comercio (para gastos) o del pagador/origen (para ingresos). Ej: "RAPPI", "EXITO" para gastos; "Nómina", "Empresa X", "Juan Pérez" para ingresos. Si no aparece un nombre específico, usa una descripción clara como "Abono nómina", "Transferencia recibida", "Depósito".
- bank: nombre del banco que emite la notificación (Davivienda, Bancolombia, Nequi, Daviplata, etc.).
- date: usa formato YYYY-MM-DD. Si no aparece fecha, devuelve null.
- cardLast4: últimos 4 dígitos de la tarjeta si aparece.
- confidence: 0.0 a 1.0 — qué tan seguro estás de que es una transacción real.

${catSection}

${accountSection}

RESPONDE SOLO JSON VÁLIDO con esta estructura exacta:
{
  "isTransaction": boolean,
  "type": "EXPENSE" | "INCOME" | "TRANSFER" | null,
  "amount": number | null,
  "merchant": string | null,
  "bank": string | null,
  "date": string | null,
  "cardLast4": string | null,
  "description": string | null,
  "categoryId": string | null,
  "accountId": string | null,
  "confidence": number,
  "reason": string
}

Si isTransaction=false, llena solo "reason" explicando por qué no es transacción.`;
}

@Injectable()
export class LlmService {
  private readonly logger = new Logger(LlmService.name);
  private readonly client: Groq;
  private readonly model: string;

  constructor(private readonly config: ConfigService) {
    const apiKey = this.config.get<string>('GROQ_API_KEY');
    if (!apiKey) {
      this.logger.warn('GROQ_API_KEY no configurada. Parser de notificaciones deshabilitado.');
    }
    this.client = new Groq({ apiKey: apiKey ?? '' });
    this.model = this.config.get<string>('LLM_MODEL') ?? 'llama-3.1-8b-instant';
  }

  async parseNotification(
    input: {
      packageName?: string;
      title?: string;
      content: string;
      postedAt?: string;
    },
    categories: CategoryHint[] = [],
    accounts: AccountHint[] = [],
  ): Promise<ParsedNotification> {
    const userPrompt = [
      input.packageName ? `App: ${input.packageName}` : null,
      input.title ? `Título: ${input.title}` : null,
      `Contenido: ${input.content}`,
      input.postedAt ? `Recibida: ${input.postedAt}` : null,
    ]
      .filter(Boolean)
      .join('\n');

    try {
      const completion = await this.client.chat.completions.create({
        model: this.model,
        temperature: 0.1,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: buildSystemPrompt(categories, accounts) },
          { role: 'user', content: userPrompt },
        ],
      });

      const raw = completion.choices[0]?.message?.content ?? '{}';
      this.logger.log(`Raw LLM response: ${raw}`);
      this.logger.log(`Categorías enviadas: ${categories.length}`);
      const parsed = JSON.parse(raw) as ParsedNotification;

      // Normalizaciones de seguridad
      if (typeof parsed.amount === 'string') {
        parsed.amount = Number((parsed.amount as unknown as string).replace(/[^\d.]/g, ''));
      }
      if (parsed.confidence == null) parsed.confidence = 0.5;

      // Validar categoryId
      if (parsed.categoryId) {
        const match = categories.find((c) => c.id === parsed.categoryId);
        if (!match) {
          this.logger.warn(
            `LLM devolvió categoryId INVÁLIDO: "${parsed.categoryId}". Se descarta.`,
          );
          parsed.categoryId = null;
        } else {
          this.logger.log(`LLM eligió categoría: "${match.name}"`);
        }
      }

      // Validar accountId
      if (parsed.accountId) {
        const match = accounts.find((a) => a.id === parsed.accountId);
        if (!match) {
          this.logger.warn(
            `LLM devolvió accountId INVÁLIDO: "${parsed.accountId}". Se descarta.`,
          );
          parsed.accountId = null;
        } else {
          this.logger.log(`LLM eligió cuenta: "${match.name}"`);
        }
      }

      return parsed;
    } catch (err) {
      this.logger.error(`Error parseando notificación: ${(err as Error).message}`);
      return {
        isTransaction: false,
        confidence: 0,
        reason: 'Error al procesar con LLM',
      };
    }
  }
}
