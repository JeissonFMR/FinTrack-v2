import { Module } from '@nestjs/common';
import { TransactionsController } from './transactions.controller';
import { TransactionsService } from './transactions.service';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { AiModule } from '../ai/ai.module';
import { CategoriesModule } from '../categories/categories.module';
import { AccountsModule } from '../accounts/accounts.module';

@Module({
  imports: [AiModule, CategoriesModule, AccountsModule],
  controllers: [TransactionsController],
  providers: [TransactionsService, WorkspaceMemberGuard],
  exports: [TransactionsService],
})
export class TransactionsModule {}
