import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import helmet from 'helmet';
import compression = require('compression');

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.use(helmet());
  app.use(compression());

  app.setGlobalPrefix('api/v1');

  app.enableCors({
    origin: (process.env.ALLOWED_ORIGINS ?? '').split(','),
    credentials: true,
  });

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`API running on http://localhost:${port}/api/v1`);
}
bootstrap();
