import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCategoryDto } from './dto/create-category.dto';

@Injectable()
export class CategoriesService {
  constructor(private readonly prisma: PrismaService) {}

  findAll(workspaceId: string) {
    return this.prisma.category.findMany({
      where: { workspaceId, parentId: null },
      include: { subcategories: true },
      orderBy: [{ type: 'asc' }, { name: 'asc' }],
    });
  }

  async findOne(workspaceId: string, id: string) {
    const category = await this.prisma.category.findFirst({
      where: { id, workspaceId },
      include: { subcategories: true },
    });
    if (!category) throw new NotFoundException('Category not found');
    return category;
  }

  create(workspaceId: string, dto: CreateCategoryDto) {
    return this.prisma.category.create({
      data: {
        workspaceId,
        name: dto.name,
        type: dto.type,
        parentId: dto.parentId,
        color: dto.color ?? '#6366F1',
        icon: dto.icon ?? 'tag',
      },
    });
  }

  async update(workspaceId: string, id: string, dto: Partial<CreateCategoryDto>) {
    await this.findOne(workspaceId, id);
    return this.prisma.category.update({ where: { id }, data: dto });
  }

  async remove(workspaceId: string, id: string) {
    const category = await this.findOne(workspaceId, id);
    if (category.isDefault) throw new NotFoundException('Cannot delete default categories');
    return this.prisma.category.delete({ where: { id } });
  }
}
