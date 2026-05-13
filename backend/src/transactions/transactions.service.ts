import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, TransactionType } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { FilterTransactionDto } from './dto/filter-transaction.dto';

@Injectable()
export class TransactionsService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(workspaceId: string, filter: FilterTransactionDto) {
    const { accountId, categoryId, type, from, to, page = 1, limit = 20 } = filter;

    const where: Prisma.TransactionWhereInput = {
      workspaceId,
      ...(accountId && { accountId }),
      ...(categoryId && { categoryId }),
      ...(type && { type }),
      ...(from || to
        ? {
            date: {
              ...(from && { gte: new Date(from) }),
              ...(to && { lte: new Date(to) }),
            },
          }
        : {}),
    };

    const [data, total] = await Promise.all([
      this.prisma.transaction.findMany({
        where,
        include: {
          account: { select: { id: true, name: true, color: true, icon: true } },
          category: { select: { id: true, name: true, color: true, icon: true } },
          createdBy: { select: { id: true, name: true } },
        },
        orderBy: { date: 'desc' },
        skip: (page - 1) * limit,
        take: limit,
      }),
      this.prisma.transaction.count({ where }),
    ]);

    return {
      data,
      meta: { total, page, limit, totalPages: Math.ceil(total / limit) },
    };
  }

  async findOne(workspaceId: string, id: string) {
    const tx = await this.prisma.transaction.findFirst({
      where: { id, workspaceId },
      include: {
        account: true,
        category: true,
        transferToAccount: { select: { id: true, name: true } },
        createdBy: { select: { id: true, name: true } },
      },
    });
    if (!tx) throw new NotFoundException('Transaction not found');
    return tx;
  }

  async create(workspaceId: string, userId: string, dto: CreateTransactionDto) {
    if (dto.type === TransactionType.TRANSFER && !dto.transferToAccountId) {
      throw new BadRequestException('Transfer requires a destination account');
    }

    return this.prisma.$transaction(async (tx) => {
      const transaction = await tx.transaction.create({
        data: {
          workspaceId,
          accountId: dto.accountId,
          categoryId: dto.categoryId,
          type: dto.type,
          amount: dto.amount,
          description: dto.description,
          date: new Date(dto.date),
          notes: dto.notes,
          transferToAccountId: dto.transferToAccountId,
          createdById: userId,
        },
      });

      if (dto.type === TransactionType.INCOME) {
        await tx.account.update({
          where: { id: dto.accountId },
          data: { balance: { increment: dto.amount } },
        });
      } else if (dto.type === TransactionType.EXPENSE) {
        await tx.account.update({
          where: { id: dto.accountId },
          data: { balance: { decrement: dto.amount } },
        });
      } else if (dto.type === TransactionType.TRANSFER && dto.transferToAccountId) {
        await tx.account.update({
          where: { id: dto.accountId },
          data: { balance: { decrement: dto.amount } },
        });
        await tx.account.update({
          where: { id: dto.transferToAccountId },
          data: { balance: { increment: dto.amount } },
        });
      }

      return transaction;
    });
  }

  async remove(workspaceId: string, id: string) {
    const transaction = await this.findOne(workspaceId, id);

    return this.prisma.$transaction(async (tx) => {
      await tx.transaction.delete({ where: { id } });

      if (transaction.type === TransactionType.INCOME) {
        await tx.account.update({
          where: { id: transaction.accountId },
          data: { balance: { decrement: Number(transaction.amount) } },
        });
      } else if (transaction.type === TransactionType.EXPENSE) {
        await tx.account.update({
          where: { id: transaction.accountId },
          data: { balance: { increment: Number(transaction.amount) } },
        });
      } else if (transaction.type === TransactionType.TRANSFER && transaction.transferToAccountId) {
        await tx.account.update({
          where: { id: transaction.accountId },
          data: { balance: { increment: Number(transaction.amount) } },
        });
        await tx.account.update({
          where: { id: transaction.transferToAccountId },
          data: { balance: { decrement: Number(transaction.amount) } },
        });
      }
    });
  }

  async getSummary(workspaceId: string, from: string, to: string) {
    const where: Prisma.TransactionWhereInput = {
      workspaceId,
      date: { gte: new Date(from), lte: new Date(to) },
    };

    const [incomeAgg, expenseAgg, byCategory] = await Promise.all([
      this.prisma.transaction.aggregate({
        where: { ...where, type: TransactionType.INCOME },
        _sum: { amount: true },
      }),
      this.prisma.transaction.aggregate({
        where: { ...where, type: TransactionType.EXPENSE },
        _sum: { amount: true },
      }),
      this.prisma.transaction.groupBy({
        by: ['categoryId'],
        where: { ...where, type: TransactionType.EXPENSE },
        _sum: { amount: true },
        orderBy: { _sum: { amount: 'desc' } },
        take: 10,
      }),
    ]);

    const totalIncome = Number(incomeAgg._sum.amount ?? 0);
    const totalExpenses = Number(expenseAgg._sum.amount ?? 0);

    return {
      totalIncome,
      totalExpenses,
      netFlow: totalIncome - totalExpenses,
      byCategory,
    };
  }
}
