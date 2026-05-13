import { Module } from '@nestjs/common';
import { TransactionsController } from './transactions.controller';
import { TransactionsService } from './transactions.service';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';

@Module({
  controllers: [TransactionsController],
  providers: [TransactionsService, WorkspaceMemberGuard],
  exports: [TransactionsService],
})
export class TransactionsModule {}
