import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma, RecurrenceFrequency } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CreateRecurringDto } from './dto/create-recurring.dto';

@Injectable()
export class RecurringTransactionsService {
  private readonly logger = new Logger(RecurringTransactionsService.name);

  constructor(private readonly prisma: PrismaService) {}

  findAll(workspaceId: string) {
    return this.prisma.recurringTransaction.findMany({
      where: { workspaceId },
      include: {
        account: { select: { id: true, name: true, color: true, icon: true } },
        category: { select: { id: true, name: true, color: true, icon: true } },
      },
      orderBy: [{ isActive: 'desc' }, { nextDueDate: 'asc' }],
    });
  }

  async findOne(workspaceId: string, id: string) {
    const rec = await this.prisma.recurringTransaction.findFirst({
      where: { id, workspaceId },
      include: {
        account: { select: { id: true, name: true, color: true, icon: true } },
        category: { select: { id: true, name: true, color: true, icon: true } },
      },
    });
    if (!rec) throw new NotFoundException('Recurring transaction not found');
    return rec;
  }

  async create(workspaceId: string, userId: string, dto: CreateRecurringDto) {
    const start = new Date(dto.startDate);
    return this.prisma.recurringTransaction.create({
      data: {
        workspaceId,
        createdById: userId,
        name: dto.name,
        type: dto.type,
        amount: dto.amount,
        accountId: dto.accountId,
        categoryId: dto.categoryId ?? null,
        description: dto.description ?? null,
        frequency: dto.frequency,
        startDate: start,
        endDate: dto.endDate ? new Date(dto.endDate) : null,
        nextDueDate: start,
        isActive: dto.isActive ?? true,
      },
    });
  }

  async update(workspaceId: string, id: string, data: Partial<CreateRecurringDto>) {
    await this.findOne(workspaceId, id);
    const updateData: Prisma.RecurringTransactionUpdateInput = {};
    if (data.name !== undefined) updateData.name = data.name;
    if (data.type !== undefined) updateData.type = data.type;
    if (data.amount !== undefined) updateData.amount = data.amount;
    if (data.accountId !== undefined) {
      updateData.account = { connect: { id: data.accountId } };
    }
    if (data.categoryId !== undefined) {
      updateData.category = data.categoryId
        ? { connect: { id: data.categoryId } }
        : { disconnect: true };
    }
    if (data.description !== undefined) updateData.description = data.description;
    if (data.frequency !== undefined) updateData.frequency = data.frequency;
    if (data.startDate !== undefined) updateData.startDate = new Date(data.startDate);
    if (data.endDate !== undefined) {
      updateData.endDate = data.endDate ? new Date(data.endDate) : null;
    }
    if (data.isActive !== undefined) updateData.isActive = data.isActive;

    return this.prisma.recurringTransaction.update({ where: { id }, data: updateData });
  }

  async remove(workspaceId: string, id: string) {
    await this.findOne(workspaceId, id);
    return this.prisma.recurringTransaction.delete({ where: { id } });
  }

  /**
   * Crea inmediatamente la transacción asociada (sin esperar al cron).
   * Útil para botón "Aplicar ahora".
   */
  async runNow(workspaceId: string, id: string) {
    const rec = await this.findOne(workspaceId, id);
    if (!rec.isActive) {
      throw new NotFoundException('La recurrente no está activa');
    }
    return this.materialize(rec.id);
  }

  /**
   * Crea la transacción real a partir de una recurrente y avanza nextDueDate.
   * Es llamado desde el cron y desde runNow.
   */
  async materialize(recurringId: string) {
    return this.prisma.$transaction(async (tx) => {
      const rec = await tx.recurringTransaction.findUnique({
        where: { id: recurringId },
      });
      if (!rec || !rec.isActive) return null;

      // Crear la transacción
      const created = await tx.transaction.create({
        data: {
          workspaceId: rec.workspaceId,
          accountId: rec.accountId,
          categoryId: rec.categoryId,
          type: rec.type,
          amount: rec.amount,
          description: rec.description ?? rec.name,
          date: rec.nextDueDate,
          recurringId: rec.id,
          createdById: rec.createdById,
        },
      });

      // Actualizar balance de la cuenta
      const delta =
        rec.type === 'INCOME'
          ? Number(rec.amount)
          : rec.type === 'EXPENSE'
            ? -Number(rec.amount)
            : 0;
      if (delta !== 0) {
        await tx.account.update({
          where: { id: rec.accountId },
          data: { balance: { increment: delta } },
        });
      }

      // Avanzar nextDueDate según frecuencia
      const next = advanceDate(rec.nextDueDate, rec.frequency);
      const isEnded = rec.endDate ? next > rec.endDate : false;

      await tx.recurringTransaction.update({
        where: { id: rec.id },
        data: {
          lastRunDate: rec.nextDueDate,
          nextDueDate: next,
          isActive: !isEnded,
        },
      });

      return created;
    });
  }

  /**
   * Llamado por el cron: encuentra todas las recurrentes activas vencidas
   * (nextDueDate <= ahora) y las materializa.
   */
  async runDue() {
    const due = await this.prisma.recurringTransaction.findMany({
      where: { isActive: true, nextDueDate: { lte: new Date() } },
      select: { id: true },
    });
    this.logger.log(`Materializando ${due.length} recurrentes vencidas`);
    let count = 0;
    for (const { id } of due) {
      try {
        const created = await this.materialize(id);
        if (created) count++;
      } catch (err) {
        this.logger.error(
          `Error materializando recurring ${id}: ${(err as Error).message}`,
        );
      }
    }
    return count;
  }
}

function advanceDate(from: Date, freq: RecurrenceFrequency): Date {
  const d = new Date(from);
  switch (freq) {
    case 'DAILY':
      d.setDate(d.getDate() + 1);
      return d;
    case 'WEEKLY':
      d.setDate(d.getDate() + 7);
      return d;
    case 'BIWEEKLY':
      d.setDate(d.getDate() + 14);
      return d;
    case 'MONTHLY':
      d.setMonth(d.getMonth() + 1);
      return d;
    case 'YEARLY':
      d.setFullYear(d.getFullYear() + 1);
      return d;
  }
}
