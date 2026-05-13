import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto } from './dto/create-category.dto';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:workspaceId/categories')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Get()
  findAll(@Param('workspaceId') workspaceId: string) {
    return this.categoriesService.findAll(workspaceId);
  }

  @Get(':id')
  findOne(@Param('workspaceId') workspaceId: string, @Param('id') id: string) {
    return this.categoriesService.findOne(workspaceId, id);
  }

  @Post()
  create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateCategoryDto) {
    return this.categoriesService.create(workspaceId, dto);
  }

  @Patch(':id')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('id') id: string,
    @Body() dto: Partial<CreateCategoryDto>,
  ) {
    return this.categoriesService.update(workspaceId, id, dto);
  }

  @Delete(':id')
  remove(@Param('workspaceId') workspaceId: string, @Param('id') id: string) {
    return this.categoriesService.remove(workspaceId, id);
  }
}
