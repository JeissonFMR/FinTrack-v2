import { AccountType } from '@prisma/client';
import { IsEnum, IsNumber, IsOptional, IsString, MaxLength, Min, MinLength } from 'class-validator';

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

  @IsOptional()
  @IsNumber()
  @Min(0)
  initialBalance?: number;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  icon?: string;
}
