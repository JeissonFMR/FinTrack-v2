import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { CreateDebtDto } from './dto/create-debt.dto';
import { DebtsService } from './debts.service';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:workspaceId/debts')
export class DebtsController {
  constructor(private readonly debtsService: DebtsService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string) {
    return this.debtsService.findAll(workspaceId);
  }

  @Get('summary')
  getSummary(@Param('workspaceId') workspaceId: string) {
    return this.debtsService.getSummary(workspaceId);
  }

  @Post()
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateDebtDto) {
    return this.debtsService.create(workspaceId, dto);
  }

  @Post(':id/payment')
  recordPayment(
    @Param('workspaceId') workspaceId: string,
    @Param('id') id: string,
    @Body('amount') amount: number,
  ) {
    return this.debtsService.recordPayment(workspaceId, id, amount);
  }

  @Patch(':id')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('id') id: string,
    @Body() dto: Partial<CreateDebtDto>,
  ) {
    return this.debtsService.update(workspaceId, id, dto);
  }

  @Delete(':id')
  remove(@Param('workspaceId') workspaceId: string, @Param('id') id: string) {
    return this.debtsService.remove(workspaceId, id);
  }
}
