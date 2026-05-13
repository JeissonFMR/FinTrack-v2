import { Module } from '@nestjs/common';
import { GoalsController } from './goals.controller';
import { GoalsService } from './goals.service';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';

@Module({
  controllers: [GoalsController],
  providers: [GoalsService, WorkspaceMemberGuard],
})
export class GoalsModule {}
