import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateDebtDto } from './dto/create-debt.dto';

@Injectable()
export class DebtsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(workspaceId: string) {
    return this.prisma.debt.findMany({
      where: { workspaceId },
      orderBy: [{ isPaid: 'asc' }, { dueDate: 'asc' }],
    });
  }

  async findOne(workspaceId: string, id: string) {
    const debt = await this.prisma.debt.findFirst({ where: { id, workspaceId } });
    if (!debt) throw new NotFoundException('Debt not found');
    return debt;
  }

  create(workspaceId: string, dto: CreateDebtDto) {
    return this.prisma.debt.create({
      data: {
        workspaceId,
        name: dto.name,
        type: dto.type,
        totalAmount: dto.totalAmount,
        remainingAmount: dto.totalAmount,
        interestRate: dto.interestRate,
        installments: dto.installments,
        paymentDay: dto.paymentDay,
        dueDate: dto.dueDate ? new Date(dto.dueDate) : undefined,
        contactName: dto.contactName,
        notes: dto.notes,
      },
    });
  }

  async recordPayment(workspaceId: string, id: string, amount: number) {
    const debt = await this.findOne(workspaceId, id);
    const remaining = Math.max(0, Number(debt.remainingAmount) - amount);
    const isPaid = remaining === 0;

    return this.prisma.debt.update({
      where: { id },
      data: { remainingAmount: remaining, isPaid },
    });
  }

  async update(workspaceId: string, id: string, dto: Partial<CreateDebtDto>) {
    await this.findOne(workspaceId, id);
    return this.prisma.debt.update({
      where: { id },
      data: {
        ...dto,
        dueDate: dto.dueDate ? new Date(dto.dueDate) : undefined,
      },
    });
  }

  async remove(workspaceId: string, id: string) {
    await this.findOne(workspaceId, id);
    return this.prisma.debt.delete({ where: { id } });
  }

  async getSummary(workspaceId: string) {
    const debts = await this.prisma.debt.findMany({
      where: { workspaceId, isPaid: false },
    });

    const iOwe = debts.filter((d) => d.type === 'OWED_BY_ME').reduce((s, d) => s + Number(d.remainingAmount), 0);
    const owedToMe = debts.filter((d) => d.type === 'OWED_TO_ME').reduce((s, d) => s + Number(d.remainingAmount), 0);

    return { iOwe: iOwe, owedToMe, netDebt: iOwe - owedToMe, debts };
  }
}
