import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../common/guards/workspace-member.guard';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { FilterTransactionDto } from './dto/filter-transaction.dto';
import { ParseNotificationDto } from './dto/parse-notification.dto';
import { TransactionsService } from './transactions.service';
import { AccountHint, CategoryHint, LlmService } from '../ai/llm.service';
import { CategoriesService } from '../categories/categories.service';
import { AccountsService } from '../accounts/accounts.service';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:workspaceId/transactions')
export class TransactionsController {
  constructor(
    private readonly transactionsService: TransactionsService,
    private readonly llmService: LlmService,
    private readonly categoriesService: CategoriesService,
    private readonly accountsService: AccountsService,
  ) {}

  @Post('parse-notification')
  async parseNotification(
    @Param('workspaceId') workspaceId: string,
    @Body() dto: ParseNotificationDto,
  ) {
    const [cats, accs] = await Promise.all([
      this.categoriesService.findAll(workspaceId),
      this.accountsService.findAll(workspaceId),
    ]);
    const catHints: CategoryHint[] = (cats as Array<{
      id: string;
      name: string;
      type: 'INCOME' | 'EXPENSE' | 'BOTH';
    }>).map((c) => ({ id: c.id, name: c.name, type: c.type }));
    const accHints: AccountHint[] = (accs as Array<{
      id: string;
      name: string;
      cardLast4: string | null;
    }>).map((a) => ({ id: a.id, name: a.name, cardLast4: a.cardLast4 }));
    return this.llmService.parseNotification(dto, catHints, accHints);
  }

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

  @Patch(':id')
  update(
    @Param('workspaceId') workspaceId: string,
    @Param('id') id: string,
    @Body() dto: Partial<CreateTransactionDto>,
  ) {
    return this.transactionsService.update(workspaceId, id, dto);
  }

  @Delete(':id')
  remove(@Param('workspaceId') workspaceId: string, @Param('id') id: string) {
    return this.transactionsService.remove(workspaceId, id);
  }
}
