import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { CreateGoalDto } from './dto/create-goal.dto';
import { GoalsService } from './goals.service';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:workspaceId/goals')
export class GoalsController {
  constructor(private readonly goalsService: GoalsService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string) {
    return this.goalsService.findAll(workspaceId);
  }

  @Post()
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateGoalDto) {
    return this.goalsService.create(workspaceId, dto);
  }

  @Post(':id/progress')
  addProgress(
    @Param('workspaceId') workspaceId: string,
    @Param('id') id: string,
    @Body('amount') amount: number,
  ) {
    return this.goalsService.addProgress(workspaceId, id, amount);
  }

  @Patch(':id')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('id') id: string,
    @Body() dto: Partial<CreateGoalDto>,
  ) {
    return this.goalsService.update(workspaceId, id, dto);
  }

  @Delete(':id')
  remove(@Param('workspaceId') workspaceId: string, @Param('id') id: string) {
    return this.goalsService.remove(workspaceId, id);
  }
}
