import { Module, OnApplicationBootstrap } from '@nestjs/common';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { RecurringTransactionsController } from './recurring-transactions.controller';
import { RecurringTransactionsCron } from './recurring-transactions.cron';
import { RecurringTransactionsService } from './recurring-transactions.service';

@Module({
  controllers: [RecurringTransactionsController],
  providers: [RecurringTransactionsService, RecurringTransactionsCron, WorkspaceMemberGuard],
  exports: [RecurringTransactionsService],
})
export class RecurringTransactionsModule implements OnApplicationBootstrap {
  constructor(private readonly service: RecurringTransactionsService) {}

  /** Ejecutar pendientes al arrancar — por si el server estuvo apagado. */
  async onApplicationBootstrap() {
    try {
      await this.service.runDue();
    } catch (_) {
      // No bloqueamos el arranque por esto.
    }
  }
}
