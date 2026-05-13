import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { WorkspaceMemberRole } from '@prisma/client';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateWorkspaceDto } from './dto/create-workspace.dto';
import { WorkspacesService } from './workspaces.service';

@UseGuards(JwtAuthGuard)
@Controller('workspaces')
export class WorkspacesController {
  constructor(private readonly workspacesService: WorkspacesService) {}

  @Get()
  findAll(@CurrentUser('id') userId: string) {
    return this.workspacesService.findAllForUser(userId);
  }

  @Get(':workspaceId')
  findOne(@Param('workspaceId') workspaceId: string, @CurrentUser('id') userId: string) {
    return this.workspacesService.findOne(workspaceId, userId);
  }

  @Post()
  create(@CurrentUser('id') userId: string, @Body() dto: CreateWorkspaceDto) {
    return this.workspacesService.create(userId, dto);
  }

  @Post(':workspaceId/members')
  invite(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser('id') userId: string,
    @Body('email') email: string,
    @Body('role') role: WorkspaceMemberRole,
  ) {
    return this.workspacesService.inviteMember(workspaceId, userId, email, role);
  }

  @Delete(':workspaceId/members/:targetUserId')
  removeMember(
    @Param('workspaceId') workspaceId: string,
    @Param('targetUserId') targetUserId: string,
    @CurrentUser('id') userId: string,
  ) {
    return this.workspacesService.removeMember(workspaceId, userId, targetUserId);
  }
}
