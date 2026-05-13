import { Injectable, NotFoundException } from '@nestjs/common';
import { GoalStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateGoalDto } from './dto/create-goal.dto';

@Injectable()
export class GoalsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(workspaceId: string) {
    return this.prisma.savingsGoal.findMany({
      where: { workspaceId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(workspaceId: string, id: string) {
    const goal = await this.prisma.savingsGoal.findFirst({ where: { id, workspaceId } });
    if (!goal) throw new NotFoundException('Goal not found');
    return goal;
  }

  create(workspaceId: string, dto: CreateGoalDto) {
    return this.prisma.savingsGoal.create({
      data: {
        workspaceId,
        name: dto.name,
        targetAmount: dto.targetAmount,
        currentAmount: dto.initialAmount ?? 0,
        deadline: dto.deadline ? new Date(dto.deadline) : undefined,
        color: dto.color ?? '#10B981',
        icon: dto.icon ?? 'target',
      },
    });
  }

  async addProgress(workspaceId: string, id: string, amount: number) {
    const goal = await this.findOne(workspaceId, id);
    const newAmount = Number(goal.currentAmount) + amount;
    const status: GoalStatus = newAmount >= Number(goal.targetAmount) ? 'COMPLETED' : 'ACTIVE';

    return this.prisma.savingsGoal.update({
      where: { id },
      data: { currentAmount: newAmount, status },
    });
  }

  async update(workspaceId: string, id: string, dto: Partial<CreateGoalDto>) {
    await this.findOne(workspaceId, id);
    return this.prisma.savingsGoal.update({
      where: { id },
      data: {
        ...dto,
        deadline: dto.deadline ? new Date(dto.deadline) : undefined,
      },
    });
  }

  async remove(workspaceId: string, id: string) {
    await this.findOne(workspaceId, id);
    return this.prisma.savingsGoal.delete({ where: { id } });
  }
}
