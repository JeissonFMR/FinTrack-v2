import { Module } from '@nestjs/common';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { AssistantController } from './assistant.controller';
import { AssistantService } from './assistant.service';

@Module({
  controllers: [AssistantController],
  providers: [AssistantService, WorkspaceMemberGuard],
})
export class AssistantModule {}
