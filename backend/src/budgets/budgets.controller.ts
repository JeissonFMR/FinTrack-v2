import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { BudgetsService } from './budgets.service';
import { CreateBudgetDto } from './dto/create-budget.dto';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:workspaceId/budgets')
export class BudgetsController {
  constructor(private readonly budgetsService: BudgetsService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string) {
    return this.budgetsService.findAll(workspaceId);
  }

  @Post()
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateBudgetDto) {
    return this.budgetsService.create(workspaceId, dto);
  }

  @Patch(':id')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('id') id: string,
    @Body() dto: Partial<CreateBudgetDto>,
  ) {
    return this.budgetsService.update(workspaceId, id, dto);
  }

  @Delete(':id')
  remove(@Param('workspaceId') workspaceId: string, @Param('id') id: string) {
    return this.budgetsService.remove(workspaceId, id);
  }
}
