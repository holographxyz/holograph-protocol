import * as z from 'zod';
import { Environment } from '@holographxyz/environment';

const envSchema = z.object({
  PRIVATE_KEY: z.string(),
  CUSTOM_ERC721_SALT: z.string().min(32, {
    message: 'Salt is required. It must be a 32-character hexadecimal string.',
  }),
  CUSTOM_ERC721_PROVIDER_URL: z.string().url(),
  HARDWARE_WALLET_ENABLED: z
    .enum(['true', 'false'])
    .default('false')
    .transform((value) => value === 'true'),
  HOLOGRAPH_ENVIRONMENT: z
    .enum([
      Environment.localhost,
      Environment.experimental,
      Environment.develop,
      Environment.testnet,
      Environment.mainnet,
    ])
    .default(Environment.develop),
});

export const parsedEnv = envSchema.parse(process.env);
