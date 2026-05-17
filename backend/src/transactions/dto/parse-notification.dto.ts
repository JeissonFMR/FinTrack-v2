import { IsOptional, IsString } from 'class-validator';

export class ParseNotificationDto {
  @IsOptional()
  @IsString()
  packageName?: string;

  @IsOptional()
  @IsString()
  title?: string;

  @IsString()
  content!: string;

  @IsOptional()
  @IsString()
  postedAt?: string;
}
