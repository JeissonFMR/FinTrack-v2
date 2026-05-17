import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { WorkspaceMemberRole } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateWorkspaceDto } from './dto/create-workspace.dto';

@Injectable()
export class WorkspacesService {
  constructor(private readonly prisma: PrismaService) {}

  async findAllForUser(userId: string) {
    return this.prisma.workspace.findMany({
      where: { members: { some: { userId } } },
      include: {
        members: { include: { user: { select: { id: true, name: true, email: true, avatarUrl: true } } } },
        _count: { select: { accounts: true, transactions: true } },
      },
    });
  }

  async findOne(workspaceId: string, userId: string) {
    const workspace = await this.prisma.workspace.findFirst({
      where: { id: workspaceId, members: { some: { userId } } },
      include: {
        members: { include: { user: { select: { id: true, name: true, email: true, avatarUrl: true } } } },
        accounts: { where: { isActive: true } },
      },
    });

    if (!workspace) throw new NotFoundException('Workspace not found');
    return workspace;
  }

  async updateName(workspaceId: string, userId: string, name: string) {
    await this.assertRole(workspaceId, userId, [WorkspaceMemberRole.OWNER, WorkspaceMemberRole.ADMIN]);
    return this.prisma.workspace.update({ where: { id: workspaceId }, data: { name } });
  }

  async create(userId: string, dto: CreateWorkspaceDto) {
    return this.prisma.$transaction(async (tx) => {
      const workspace = await tx.workspace.create({
        data: { name: dto.name, currency: dto.currency ?? 'COP' },
      });

      await tx.workspaceMember.create({
        data: { workspaceId: workspace.id, userId, role: WorkspaceMemberRole.OWNER },
      });

      return workspace;
    });
  }

  async inviteMember(workspaceId: string, requesterId: string, inviteeEmail: string, role: WorkspaceMemberRole) {
    await this.assertRole(workspaceId, requesterId, [WorkspaceMemberRole.OWNER, WorkspaceMemberRole.ADMIN]);

    const invitee = await this.prisma.user.findUnique({ where: { email: inviteeEmail } });
    if (!invitee) throw new NotFoundException('User not found');

    return this.prisma.workspaceMember.upsert({
      where: { workspaceId_userId: { workspaceId, userId: invitee.id } },
      create: { workspaceId, userId: invitee.id, role },
      update: { role },
    });
  }

  async removeMember(workspaceId: string, requesterId: string, targetUserId: string) {
    await this.assertRole(workspaceId, requesterId, [WorkspaceMemberRole.OWNER]);

    if (requesterId === targetUserId) throw new ForbiddenException('Cannot remove yourself as owner');

    return this.prisma.workspaceMember.delete({
      where: { workspaceId_userId: { workspaceId, userId: targetUserId } },
    });
  }

  private async assertRole(workspaceId: string, userId: string, roles: WorkspaceMemberRole[]) {
    const membership = await this.prisma.workspaceMember.findUnique({
      where: { workspaceId_userId: { workspaceId, userId } },
    });

    if (!membership || !roles.includes(membership.role)) {
      throw new ForbiddenException('Insufficient permissions');
    }
  }
}
