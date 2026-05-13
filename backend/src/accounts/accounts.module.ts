import { Module } from '@nestjs/common';
import { AccountsController } from './accounts.controller';
import { AccountsService } from './accounts.service';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';

@Module({
  controllers: [AccountsController],
  providers: [AccountsService, WorkspaceMemberGuard],
  exports: [AccountsService],
})
export class AccountsModule {}
