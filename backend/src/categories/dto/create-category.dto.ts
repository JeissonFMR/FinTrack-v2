import { CategoryType } from '@prisma/client';
import { IsEnum, IsOptional, IsString, IsUUID, MaxLength, MinLength } from 'class-validator';

export class CreateCategoryDto {
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @IsEnum(CategoryType)
  type: CategoryType;

  @IsOptional()
  @IsUUID()
  parentId?: string;

  @IsOptional()
  @IsString()
  color?: string;

  @IsOptional()
  @IsString()
  icon?: string;
}
