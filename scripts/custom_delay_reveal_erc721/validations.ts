import * as z from 'zod';
import { ZodError } from 'zod';
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

export const FileColumnsSchema = z.object({
  ['BatchId']: z.number(),
  ['Name']: z.string().trim(),
  ['Range']: z.number(),
  ['PlaceholderURI Path']: z.string().trim(),
  ['RevealURI Path']: z.string().trim(),
  ['Key']: z.string().trim(),
  ['ProvenanceHash']: z.string().trim().optional(),
  ['EncryptedURI']: z.string().trim().optional(),
  ['Should Decrypt']: z.boolean(),
});

export type FileColumnsType = z.infer<typeof FileColumnsSchema>;

export function validateHeader(headerKeys: string[]): void {
  const expectedKeys = Object.keys(FileColumnsSchema.shape);

  for (let i = 0; i < headerKeys.length; i++) {
    if (headerKeys[i].trim() !== expectedKeys[i]) {
      throw new Error(
        `Header column name mismatch at column ${i + 1}. Expected: ${expectedKeys[i]}, Found: ${headerKeys[i]}`
      );
    }
  }
}

export async function parseRowsContent(lines: string[][]) {
  const data = lines.map((line) => {
    const [batchId, name, range, placeholderUriPath, revealUriPath, key, provenanceHash, encryptedUri, shouldDecrypt] =
      line;
    return {
      ['BatchId']: parseInt(batchId),
      ['Name']: name,
      ['Range']: parseInt(range),
      ['PlaceholderURI Path']: placeholderUriPath,
      ['RevealURI Path']: revealUriPath,
      ['Key']: key,
      ['ProvenanceHash']: provenanceHash,
      ['EncryptedURI']: encryptedUri,
      ['Should Decrypt']: shouldDecrypt.toLowerCase() === 'true',
    };
  });

  const validatedData: FileColumnsType[] = data.map((row, index) => {
    try {
      const parsedRow: FileColumnsType = FileColumnsSchema.parse(row);
      return parsedRow;
    } catch (error) {
      if (error instanceof ZodError) {
        console.error(`Validation error at line ${index}: `, error);
      }
      //throw error;
      throw new Error(`Row ${index + 1} has an error`);
    }
  });

  return validatedData;
}

export async function parseFileContent(data: string[][]) {
  if (data.length === 0) {
    throw new Error(`File is empty!`);
  }
  const [headerKeys, ...lines] = data;

  console.log(`Validating header...`);
  validateHeader(headerKeys.filter(Boolean));

  console.log(`Validating rows...`);
  const parsedRows: FileColumnsType[] = await parseRowsContent(lines);
  return parsedRows;
}
