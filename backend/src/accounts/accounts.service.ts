import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateAccountDto } from './dto/create-account.dto';

@Injectable()
export class AccountsService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(workspaceId: string) {
    return this.prisma.account.findMany({
      where: { workspaceId, isActive: true },
      orderBy: { name: 'asc' },
    });
  }

  async findOne(workspaceId: string, id: string) {
    const account = await this.prisma.account.findFirst({ where: { id, workspaceId } });
    if (!account) throw new NotFoundException('Account not found');
    return account;
  }

  create(workspaceId: string, dto: CreateAccountDto) {
    return this.prisma.account.create({
      data: {
        workspaceId,
        name: dto.name,
        type: dto.type,
        currency: dto.currency ?? 'COP',
        balance: dto.initialBalance ?? 0,
        color: dto.color ?? '#6366F1',
        icon: dto.icon ?? 'wallet',
        cardLast4: dto.cardLast4 ?? null,
      },
    });
  }

  async update(workspaceId: string, id: string, data: Partial<CreateAccountDto>) {
    await this.findOne(workspaceId, id);
    return this.prisma.account.update({ where: { id }, data });
  }

  async archive(workspaceId: string, id: string) {
    await this.findOne(workspaceId, id);
    return this.prisma.account.update({ where: { id }, data: { isActive: false } });
  }

  async getSummary(workspaceId: string) {
    const accounts = await this.prisma.account.findMany({
      where: { workspaceId, isActive: true },
      select: { id: true, name: true, type: true, balance: true, currency: true, color: true, icon: true, cardLast4: true },
    });

    const totalBalance = accounts.reduce((sum, a) => sum + Number(a.balance), 0);

    return { accounts, totalBalance };
  }
}
