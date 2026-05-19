import { AccountType } from '@prisma/client';
import { IsEnum, IsNumber, IsOptional, IsString, Length, MaxLength, MinLength } from 'class-validator';

export class CreateAccountDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @IsEnum(AccountType)
  type: AccountType;

  @IsOptional()
  @IsString()
  currency?: string;

  // Acepta negativo para tarjetas de crédito (saldo negativo = deuda)
  @IsOptional()
  @IsNumber()
  initialBalance?: number;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  icon?: string;

  @IsOptional()
  @IsString()
  @Length(4, 4)
  cardLast4?: string;
}
