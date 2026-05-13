import { Module } from '@nestjs/common';
import { BudgetsController } from './budgets.controller';
import { BudgetsService } from './budgets.service';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';

@Module({
  controllers: [BudgetsController],
  providers: [BudgetsService, WorkspaceMemberGuard],
})
export class BudgetsModule {}
