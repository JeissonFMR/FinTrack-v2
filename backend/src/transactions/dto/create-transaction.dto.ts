import { TransactionType } from '@prisma/client';
import {
  IsDateString,
  IsEnum,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  MaxLength,
} from 'class-validator';

export class CreateTransactionDto {
  @IsUUID()
  accountId: string;

  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsEnum(TransactionType)
  type: TransactionType;

  @IsNumber()
  @IsPositive()
  amount: number;

  @IsString()
  @MaxLength(255)
  description: string;

  @IsDateString()
  date: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsUUID()
  transferToAccountId?: string;
}
