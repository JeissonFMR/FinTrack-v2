import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Prisma } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegisterDto } from './dto/register.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async register(dto: RegisterDto) {
    const exists = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (exists) throw new ConflictException('Email already registered');

    const passwordHash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.$transaction(async (tx) => {
      const newUser = await tx.user.create({
        data: { email: dto.email, name: dto.name, passwordHash },
      });

      const workspace = await tx.workspace.create({
        data: { name: `${dto.name}'s Workspace` },
      });

      await tx.workspaceMember.create({
        data: { workspaceId: workspace.id, userId: newUser.id, role: 'OWNER' },
      });

      await this.seedDefaultCategories(tx, workspace.id);

      return newUser;
    });

    return this.generateTokens(user.id, user.email);
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({ where: { email: dto.email } });
    if (!user) throw new UnauthorizedException('Invalid credentials');

    const valid = await bcrypt.compare(dto.password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');

    return this.generateTokens(user.id, user.email);
  }

  async refresh(token: string) {
    // Defensa: si llega vacío o no string, no consultar BD
    if (!token || typeof token !== 'string') {
      throw new UnauthorizedException('Invalid refresh token');
    }

    let stored;
    try {
      stored = await this.prisma.refreshToken.findUnique({ where: { token } });
    } catch (_) {
      // Cualquier error de Prisma en esta consulta es 401, no 500
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (!stored || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    // deleteMany es idempotente: no falla si el registro ya no existe (race condition con refresh paralelo)
    await this.prisma.refreshToken.deleteMany({ where: { token } });

    const user = await this.prisma.user.findUnique({
      where: { id: stored.userId },
    });
    if (!user) {
      throw new UnauthorizedException('User no longer exists');
    }

    return this.generateTokens(user.id, user.email);
  }

  async logout(token: string) {
    await this.prisma.refreshToken.deleteMany({ where: { token } });
  }

  async changePassword(userId: string, currentPassword: string, newPassword: string) {
    const user = await this.prisma.user.findUniqueOrThrow({ where: { id: userId } });
    const valid = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Contraseña actual incorrecta');
    const passwordHash = await bcrypt.hash(newPassword, 12);
    await this.prisma.user.update({ where: { id: userId }, data: { passwordHash } });
    return { message: 'Contraseña actualizada' };
  }

  private async generateTokens(userId: string, email: string) {
    const payload = { sub: userId, email };
    const accessSecret = this.config.getOrThrow<string>('JWT_ACCESS_SECRET');
    const refreshSecret = this.config.getOrThrow<string>('JWT_REFRESH_SECRET');
    const accessExpiresIn = this.config.get<string>('JWT_ACCESS_EXPIRES_IN', '15m');
    const refreshExpiresIn = this.config.get<string>('JWT_REFRESH_EXPIRES_IN', '7d');

    const [accessToken, refreshToken] = await Promise.all([
      this.jwt.signAsync(payload, { secret: accessSecret, expiresIn: accessExpiresIn as unknown as number }),
      this.jwt.signAsync(payload, { secret: refreshSecret, expiresIn: refreshExpiresIn as unknown as number }),
    ]);

    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);

    await this.prisma.refreshToken.create({
      data: { token: refreshToken, userId, expiresAt },
    });

    return { accessToken, refreshToken };
  }

  private async seedDefaultCategories(tx: Prisma.TransactionClient, workspaceId: string) {
    const defaults = [
      { name: 'Alimentación', type: 'EXPENSE' as const, icon: 'utensils', color: '#EF4444' },
      { name: 'Transporte', type: 'EXPENSE' as const, icon: 'car', color: '#F97316' },
      { name: 'Vivienda', type: 'EXPENSE' as const, icon: 'home', color: '#EAB308' },
      { name: 'Salud', type: 'EXPENSE' as const, icon: 'heart', color: '#EC4899' },
      { name: 'Entretenimiento', type: 'EXPENSE' as const, icon: 'tv', color: '#8B5CF6' },
      { name: 'Educación', type: 'EXPENSE' as const, icon: 'book', color: '#06B6D4' },
      { name: 'Ropa', type: 'EXPENSE' as const, icon: 'shirt', color: '#84CC16' },
      { name: 'Servicios', type: 'EXPENSE' as const, icon: 'zap', color: '#F59E0B' },
      { name: 'Otros gastos', type: 'EXPENSE' as const, icon: 'more-horizontal', color: '#6B7280' },
      { name: 'Salario', type: 'INCOME' as const, icon: 'briefcase', color: '#10B981' },
      { name: 'Freelance', type: 'INCOME' as const, icon: 'laptop', color: '#3B82F6' },
      { name: 'Inversiones', type: 'INCOME' as const, icon: 'trending-up', color: '#6366F1' },
      { name: 'Otros ingresos', type: 'INCOME' as const, icon: 'plus-circle', color: '#14B8A6' },
    ];

    await tx.category.createMany({
      data: defaults.map((c) => ({ ...c, workspaceId, isDefault: true })),
    });
  }
}
