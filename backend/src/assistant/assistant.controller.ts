import { Body, Controller, Param, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { AssistantService } from './assistant.service';
import { AskDto } from './dto/ask.dto';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:workspaceId/assistant')
export class AssistantController {
  constructor(private readonly service: AssistantService) {}

  @Post('ask')
  ask(@Param('workspaceId') workspaceId: string, @Body() dto: AskDto) {
    return this.service.ask(workspaceId, dto.question);
  }
}
