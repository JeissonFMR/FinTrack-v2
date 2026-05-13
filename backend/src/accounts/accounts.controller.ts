import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { AccountsService } from './accounts.service';
import { CreateAccountDto } from './dto/create-account.dto';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:workspaceId/accounts')
export class AccountsController {
  constructor(private readonly accountsService: AccountsService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string) {
    return this.accountsService.findAll(workspaceId);
  }

  @Get('summary')
  getSummary(@Param('workspaceId') workspaceId: string) {
    return this.accountsService.getSummary(workspaceId);
  }

  @Get(':id')
  findOne(@Param('workspaceId') workspaceId: string, @Param('id') id: string) {
    return this.accountsService.findOne(workspaceId, id);
  }

  @Post()
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateAccountDto) {
    return this.accountsService.create(workspaceId, dto);
  }

  @Patch(':id')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('id') id: string,
    @Body() dto: Partial<CreateAccountDto>,
  ) {
    return this.accountsService.update(workspaceId, id, dto);
  }

  @Delete(':id')
  archive(@Param('workspaceId') workspaceId: string, @Param('id') id: string) {
    return this.accountsService.archive(workspaceId, id);
  }
}
