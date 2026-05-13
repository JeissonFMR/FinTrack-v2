import { IsDateString, IsNumber, IsOptional, IsPositive, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateGoalDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @IsNumber()
  @IsPositive()
  targetAmount: number;

  @IsOptional()
  @IsNumber()
  @IsPositive()
  initialAmount?: number;

  @IsOptional()
  @IsDateString()
  deadline?: string;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  icon?: string;
}
