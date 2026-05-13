import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { FilterTransactionDto } from './dto/filter-transaction.dto';
import { TransactionsService } from './transactions.service';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:workspaceId/transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @Get()
  findAll(
    @Param('workspaceId') workspaceId: string,
    @Query() filter: FilterTransactionDto,
  ) {
    return this.transactionsService.findAll(workspaceId, filter);
  }

  @Get('summary')
  getSummary(
    @Param('workspaceId') workspaceId: string,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    return this.transactionsService.getSummary(workspaceId, from, to);
  }

  @Get(':id')
  findOne(@Param('workspaceId') workspaceId: string, @Param('id') id: string) {
    return this.transactionsService.findOne(workspaceId, id);
  }

  @Post()
  create(
    @Param('workspaceId') workspaceId: string,
    @CurrentUser('id') userId: string,
    @Body() dto: CreateTransactionDto,
  ) {
    return this.transactionsService.create(workspaceId, userId, dto);
  }

  @Delete(':id')
  remove(@Param('workspaceId') workspaceId: string, @Param('id') id: string) {
    return this.transactionsService.remove(workspaceId, id);
  }
}
