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

  /**
   * Parser de transacciones por voz. El usuario habla algo libre como
   * "Gasté 25 mil en almuerzo en Crepes" o "Recibí 3 millones de salario".
   * Devuelve la transacción estructurada con categoría sugerida.
   */
  async parseVoiceTransaction(
    text: string,
    categories: CategoryHint[] = [],
    accounts: AccountHint[] = [],
  ): Promise<ParsedNotification> {
    const today = new Date().toISOString().split('T')[0];

    const catList = categories.length === 0
      ? 'El usuario no tiene categorías. Devuelve categoryId: null.'
      : `CATEGORÍAS DEL USUARIO (elige una; si ninguna encaja, devuelve null):
${categories.map((c) => `- id="${c.id}" → "${c.name}" (${c.type})`).join('\n')}`;

    const accList = accounts.length === 0
      ? 'El usuario no tiene cuentas registradas.'
      : `CUENTAS DEL USUARIO:
${accounts.map((a) => `- id="${a.id}" → "${a.name}"`).join('\n')}`;

    const systemPrompt = `Eres un asistente que convierte la voz del usuario en una transacción financiera estructurada.

El usuario habla libre, por ejemplo:
- "Gasté 25 mil en almuerzo"
- "20.000 en Uber"
- "Recibí 3 millones de salario"
- "Pagué 80 mil de gasolina en Terpel"
- "Compré pan en la panadería por 5 mil pesos"

REGLAS:
- Detecta monto en cualquier formato: "25 mil" = 25000, "3 millones" = 3000000, "5k" = 5000, "1.5 millones" = 1500000.
- Determina type:
  - EXPENSE si menciona gasté, pagué, compré, salió, costó
  - INCOME si menciona recibí, me llegó, me pagaron, salario, transferencia recibida
  - TRANSFER si menciona "pasé/transferí X a Y" entre cuentas propias
- merchant/description: extrae lo más informativo posible.
- date: usa "${today}" siempre, a menos que el usuario diga "ayer" o una fecha explícita.
- ${catList}
- ${accList}

Para categoryId — elige el id (NO inventes) basándote en el contexto del comercio/descripción:

🍽️ ALIMENTACIÓN — palabras: almuerzo, desayuno, cena, comida, mercado, restaurante, panadería, café, refrigerio, snack, rappi, mcdonalds, dominos, kfc, exito, jumbo, ara, d1, olimpica, carulla, súper, supermercado
🚗 TRANSPORTE — palabras: uber, didi, taxi, cabify, gasolina, terpel, esso, mio, transmilenio, peaje, tiquete bus, sitp, parqueadero
🏠 VIVIENDA — palabras: arriendo, administración, EPM, gas, agua, luz, codensa, energía
💊 SALUD — palabras: médico, farmacia, drogas, droguería, EPS, doctor, hospital, dentista, cita médica, gimnasio, gym
🎬 ENTRETENIMIENTO — palabras: netflix, spotify, hbo, disney, cine, película, concierto, juego, playstation
📚 EDUCACIÓN — palabras: universidad, colegio, curso, libro, platzi, coursera
👕 ROPA — palabras: ropa, zapatos, zara, h&m, falabella, camiseta
🔌 SERVICIOS — palabras: internet, claro, movistar, teléfono, datos, plan celular
💵 SALARIO — palabras: salario, nómina, sueldo, pago mensual, quincena
💼 FREELANCE — palabras: freelance, proyecto, consultoría

PROCESO:
1. Lee el texto del usuario
2. Busca palabras clave de la lista arriba
3. Mapea a la categoría correspondiente
4. Busca esa categoría EXACTAMENTE en la lista del usuario (por nombre)
5. Copia su id literal en categoryId

EJEMPLOS CONCRETOS:
- "gasté 30 mil en almuerzo" → almuerzo está en ALIMENTACIÓN → busca categoría con name="Alimentación" → su id
- "Uber 15 mil" → uber está en TRANSPORTE → busca categoría con name="Transporte" → su id
- "compré tenis" → tenis (zapatos) está en ROPA → busca "Ropa"
- "vacuna del perro 80 mil" → no encaja en ninguna categoría obvia → categoryId: null, categorySuggestion: "Mascotas"

Si dudas o ninguna categoría encaja claramente, devuelve categoryId: null.

Para accountId:
- Si el usuario MENCIONA una cuenta (ej: "en mi davivienda", "con la tarjeta de crédito", "de mi nequi"), busca esa cuenta por nombre en la lista del usuario.
- Si no menciona ninguna, devuelve accountId: null.

RESPONDE SOLO JSON con esta estructura:
{
  "isTransaction": boolean,
  "type": "EXPENSE" | "INCOME" | "TRANSFER" | null,
  "amount": number | null,
  "merchant": string | null,
  "description": string | null,
  "date": string | null,
  "categoryId": string | null,
  "categorySuggestion": string | null,
  "accountId": string | null,
  "confidence": number,
  "reason": string
}

Si "isTransaction" es false (no entendiste o no es una transacción), llena "reason".
Si no hay categoryId pero crees que debería existir una categoría, sugiere su nombre en "categorySuggestion" (ej: "Salud", "Mascotas").`;

    try {
      // Usar el modelo grande (70B) para parseo de voz — mejor entendimiento
      // que el 8B y maneja mejor variaciones de español hablado.
      const voiceModel =
        this.config.get<string>('LLM_MODEL_VOICE') ??
        this.config.get<string>('LLM_MODEL_SQL') ??
        'llama-3.3-70b-versatile';

      const completion = await this.client.chat.completions.create({
        model: voiceModel,
        temperature: 0.1,
        response_format: { type: 'json_object' },
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: text },
        ],
      });

      const raw = completion.choices[0]?.message?.content ?? '{}';
      this.logger.log(`Voice (${voiceModel}) parse raw: ${raw}`);
      const parsed = JSON.parse(raw) as ParsedNotification & {
        categorySuggestion?: string;
      };

      if (typeof parsed.amount === 'string') {
        parsed.amount = Number((parsed.amount as unknown as string).replace(/[^\d.]/g, ''));
      }
      if (parsed.confidence == null) parsed.confidence = 0.5;

      // Validar categoryId
      if (parsed.categoryId && !categories.find((c) => c.id === parsed.categoryId)) {
        parsed.categoryId = null;
      }
      // Validar accountId
      if (parsed.accountId && !accounts.find((a) => a.id === parsed.accountId)) {
        parsed.accountId = null;
      }

      return parsed;
    } catch (err) {
      this.logger.error(`Error parseando voz: ${(err as Error).message}`);
      return {
        isTransaction: false,
        confidence: 0,
        reason: 'No entendí, intenta de nuevo',
      };
    }
  }

  /** Helper: usa el modelo de SQL si está definido, sino el de respuesta. */
  private sqlOrSql(): string {
    return this.config.get<string>('LLM_MODEL') ?? 'llama-3.1-8b-instant';
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
