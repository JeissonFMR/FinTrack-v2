import { IsString, MaxLength, MinLength } from 'class-validator';

export class ParseVoiceDto {
  @IsString()
  @MinLength(2)
  @MaxLength(500)
  text!: string;
}
