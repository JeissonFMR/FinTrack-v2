import { BudgetPeriod } from '@prisma/client';
import { IsDateString, IsEnum, IsInt, IsNumber, IsOptional, IsPositive, IsUUID, Max, Min } from 'class-validator';

export class CreateBudgetDto {
  @IsUUID()
  categoryId: string;

  @IsNumber()
  @IsPositive()
  amount: number;

  @IsEnum(BudgetPeriod)
  period: BudgetPeriod;

  @IsDateString()
  startDate: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  alertAt?: number;
}
