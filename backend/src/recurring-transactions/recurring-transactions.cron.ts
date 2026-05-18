import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { RecurringTransactionsService } from './recurring-transactions.service';

@Injectable()
export class RecurringTransactionsCron {
  private readonly logger = new Logger(RecurringTransactionsCron.name);

  constructor(private readonly service: RecurringTransactionsService) {}

  /**
   * Cada día a las 00:05 procesa las recurrentes vencidas.
   * También se ejecuta una vez al arrancar la app para no perder ninguna.
   */
  @Cron(CronExpression.EVERY_DAY_AT_MIDNIGHT)
  async handleDaily() {
    this.logger.log('Cron diario de recurrentes ejecutándose...');
    const count = await this.service.runDue();
    this.logger.log(`Cron diario: ${count} transacciones creadas`);
  }
}
