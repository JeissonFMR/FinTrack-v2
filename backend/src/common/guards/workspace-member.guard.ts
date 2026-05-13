import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class WorkspaceMemberGuard implements CanActivate {
  constructor(private readonly prisma: PrismaService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const userId: string = request.user?.id;
    const workspaceId: string = request.params?.workspaceId;

    if (!userId || !workspaceId) return false;

    const membership = await this.prisma.workspaceMember.findUnique({
      where: { workspaceId_userId: { workspaceId, userId } },
    });

    if (!membership) throw new ForbiddenException('Not a workspace member');

    request.workspaceMembership = membership;
    return true;
  }
}
