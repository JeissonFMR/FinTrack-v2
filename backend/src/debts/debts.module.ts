import { Module } from '@nestjs/common';
import { DebtsController } from './debts.controller';
import { DebtsService } from './debts.service';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';

@Module({
  controllers: [DebtsController],
  providers: [DebtsService, WorkspaceMemberGuard],
})
export class DebtsModule {}
