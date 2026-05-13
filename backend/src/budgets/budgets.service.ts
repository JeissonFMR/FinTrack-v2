import { Injectable, NotFoundException } from '@nestjs/common';
import { BudgetPeriod, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateBudgetDto } from './dto/create-budget.dto';

@Injectable()
export class BudgetsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(workspaceId: string) {
    const budgets = await this.prisma.budget.findMany({
      where: { workspaceId },
      include: { category: { select: { id: true, name: true, color: true, icon: true } } },
      orderBy: { startDate: 'desc' },
    });

    const enriched = await Promise.all(
      budgets.map(async (budget) => {
        const spent = await this.getSpentAmount(workspaceId, budget.categoryId, budget.period, budget.startDate);
        const percentage = Math.min(Math.round((spent / Number(budget.amount)) * 100), 999);
        return { ...budget, spent, percentage };
      }),
    );

    return enriched;
  }

  async create(workspaceId: string, dto: CreateBudgetDto) {
    return this.prisma.budget.create({
      data: {
        workspaceId,
        categoryId: dto.categoryId,
        amount: dto.amount,
        period: dto.period,
        startDate: new Date(dto.startDate),
        alertAt: dto.alertAt ?? 80,
      },
      include: { category: true },
    });
  }

  async update(workspaceId: string, id: string, dto: Partial<CreateBudgetDto>) {
    const budget = await this.prisma.budget.findFirst({ where: { id, workspaceId } });
    if (!budget) throw new NotFoundException('Budget not found');

    return this.prisma.budget.update({ where: { id }, data: dto });
  }

  async remove(workspaceId: string, id: string) {
    const budget = await this.prisma.budget.findFirst({ where: { id, workspaceId } });
    if (!budget) throw new NotFoundException('Budget not found');
    return this.prisma.budget.delete({ where: { id } });
  }

  private async getSpentAmount(
    workspaceId: string,
    categoryId: string,
    period: BudgetPeriod,
    startDate: Date,
  ): Promise<number> {
    const endDate = this.getPeriodEndDate(startDate, period);

    const agg = await this.prisma.transaction.aggregate({
      where: {
        workspaceId,
        categoryId,
        type: 'EXPENSE',
        date: { gte: startDate, lte: endDate },
      },
      _sum: { amount: true },
    });

    return Number(agg._sum.amount ?? 0);
  }

  private getPeriodEndDate(start: Date, period: BudgetPeriod): Date {
    const end = new Date(start);
    if (period === 'WEEKLY') end.setDate(end.getDate() + 7);
    else if (period === 'MONTHLY') end.setMonth(end.getMonth() + 1);
    else if (period === 'YEARLY') end.setFullYear(end.getFullYear() + 1);
    return end;
  }
}
