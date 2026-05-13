import { DebtType } from '@prisma/client';
import {
  IsBoolean,
  IsDateString,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  Max,
  MaxLength,
  Min,
  MinLength,
} from 'class-validator';

export class CreateDebtDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @IsEnum(DebtType)
  type: DebtType;

  @IsNumber()
  @IsPositive()
  totalAmount: number;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  interestRate?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  installments?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(31)
  paymentDay?: number;

  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @IsOptional()
  @IsString()
  contactName?: string;

  @IsOptional()
  @IsString()
  notes?: string;
}
