import { Module } from '@nestjs/common';
import { CategoriesController } from './categories.controller';
import { CategoriesService } from './categories.service';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';

@Module({
  controllers: [CategoriesController],
  providers: [CategoriesService, WorkspaceMemberGuard],
  exports: [CategoriesService],
})
export class CategoriesModule {}
