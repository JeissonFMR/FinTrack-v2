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
  confidence?: number;
  reason?: string;
}

const SYSTEM_PROMPT = `Eres un parser experto de notificaciones bancarias en español (Colombia).
Analizas el título y contenido de una notificación push y determinas si representa una transacción financiera real.

REGLAS:
- Solo cuenta como transacción: compras, pagos, transferencias enviadas/recibidas, retiros, depósitos.
- NO cuentan: OTPs, códigos de verificación, promociones, notificaciones de seguridad, recordatorios, saldos consultados.
- type=EXPENSE: pagos, compras, retiros, transferencias enviadas.
- type=INCOME: depósitos, transferencias recibidas, abonos.
- type=TRANSFER: movimientos entre cuentas propias del mismo banco.
- amount: extrae el monto numérico (sin signo, sin separadores de miles, decimales con punto).
- merchant: nombre del comercio o de la persona/entidad.
- bank: nombre del banco que emite la notificación (Davivienda, Bancolombia, Nequi, Daviplata, etc.).
- date: usa formato YYYY-MM-DD. Si no aparece fecha, devuelve null.
- cardLast4: últimos 4 dígitos de la tarjeta si aparece.
- confidence: 0.0 a 1.0 — qué tan seguro estás de que es una transacción real.

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
  "confidence": number,
  "reason": string
}

Si isTransaction=false, llena solo "reason" explicando por qué no es transacción.`;

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

  async parseNotification(input: {
    packageName?: string;
    title?: string;
    content: string;
    postedAt?: string;
  }): Promise<ParsedNotification> {
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
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: userPrompt },
        ],
      });

      const raw = completion.choices[0]?.message?.content ?? '{}';
      const parsed = JSON.parse(raw) as ParsedNotification;

      // Normalizaciones de seguridad
      if (typeof parsed.amount === 'string') {
        parsed.amount = Number((parsed.amount as unknown as string).replace(/[^\d.]/g, ''));
      }
      if (parsed.confidence == null) parsed.confidence = 0.5;

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
