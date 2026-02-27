import os from 'os';
import path from 'path';
import { promises as fs } from 'fs';

export interface PluginMetadata {
  placeName?: string;
  placeId?: number;
  gameId?: string;
  jobId?: string;
  updatedAt: number;
}

export interface InstanceRegistryEntry {
  instanceId: string;
  pid: number;
  host: string;
  port: number;
  startedAt: number;
  lastSeenAt: number;
  mcpServerActive: boolean;
  pluginConnected: boolean;
  lastPluginActivity: number;
  pluginMetadata?: PluginMetadata;
}

export interface InstanceRegistryUpdate {
  pid?: number;
  host?: string;
  port?: number;
  startedAt?: number;
  lastSeenAt?: number;
  mcpServerActive?: boolean;
  pluginConnected?: boolean;
  lastPluginActivity?: number;
  pluginMetadata?: PluginMetadata | null;
}

export interface InstanceRegistryOptions {
  registryPath?: string;
  staleMs?: number;
}

interface RegistryFileData {
  version: 1;
  instances: Record<string, InstanceRegistryEntry>;
}

const DEFAULT_STALE_MS = 20_000;
const LOCK_TIMEOUT_MS = 2_000;
const LOCK_STALE_MS = 5_000;

function sleep(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

function createEmptyRegistry(): RegistryFileData {
  return {
    version: 1,
    instances: {},
  };
}

export class InstanceRegistry {
  private readonly registryPath: string;
  private readonly lockPath: string;
  private readonly staleMs: number;

  constructor(options: InstanceRegistryOptions = {}) {
    const defaultRoot = path.join(os.tmpdir(), 'robloxstudio-mcp');
    this.registryPath = options.registryPath
      ?? process.env.ROBLOX_STUDIO_REGISTRY_PATH
      ?? path.join(defaultRoot, 'instances.json');
    this.lockPath = `${this.registryPath}.lock`;
    this.staleMs = options.staleMs ?? DEFAULT_STALE_MS;
  }

  getPath() {
    return this.registryPath;
  }

  async registerInstance(entry: InstanceRegistryEntry): Promise<InstanceRegistryEntry> {
    return this.withLock(async () => {
      const now = Date.now();
      const data = await this.readRegistryUnlocked();
      this.pruneStaleUnlocked(data, now);

      const normalized: InstanceRegistryEntry = {
        ...entry,
        startedAt: entry.startedAt || now,
        lastSeenAt: entry.lastSeenAt || now,
        lastPluginActivity: entry.lastPluginActivity || 0,
      };

      data.instances[entry.instanceId] = normalized;
      await this.writeRegistryUnlocked(data);
      return normalized;
    });
  }

  async updateInstance(instanceId: string, updates: InstanceRegistryUpdate): Promise<InstanceRegistryEntry | null> {
    return this.withLock(async () => {
      const now = Date.now();
      const data = await this.readRegistryUnlocked();
      this.pruneStaleUnlocked(data, now);

      const existing = data.instances[instanceId];
      if (!existing) {
        return null;
      }

      const { pluginMetadata: metadataUpdate, ...remainingUpdates } = updates;
      const next: InstanceRegistryEntry = {
        ...existing,
        ...remainingUpdates,
        instanceId,
        lastSeenAt: updates.lastSeenAt ?? now,
      };

      if (metadataUpdate === null) {
        delete next.pluginMetadata;
      } else if (metadataUpdate) {
        next.pluginMetadata = metadataUpdate;
      }

      data.instances[instanceId] = next;
      await this.writeRegistryUnlocked(data);
      return next;
    });
  }

  async heartbeat(instanceId: string, updates: InstanceRegistryUpdate = {}): Promise<InstanceRegistryEntry | null> {
    return this.updateInstance(instanceId, {
      ...updates,
      lastSeenAt: Date.now(),
    });
  }

  async listInstances(): Promise<InstanceRegistryEntry[]> {
    return this.withLock(async () => {
      const now = Date.now();
      const data = await this.readRegistryUnlocked();
      const changed = this.pruneStaleUnlocked(data, now);
      if (changed) {
        await this.writeRegistryUnlocked(data);
      }

      return Object
        .values(data.instances)
        .sort((a, b) => a.port - b.port);
    });
  }

  async getInstance(instanceId: string): Promise<InstanceRegistryEntry | null> {
    return this.withLock(async () => {
      const now = Date.now();
      const data = await this.readRegistryUnlocked();
      const changed = this.pruneStaleUnlocked(data, now);
      if (changed) {
        await this.writeRegistryUnlocked(data);
      }

      return data.instances[instanceId] ?? null;
    });
  }

  async removeInstance(instanceId: string): Promise<void> {
    await this.withLock(async () => {
      const data = await this.readRegistryUnlocked();
      if (!data.instances[instanceId]) {
        return;
      }
      delete data.instances[instanceId];
      await this.writeRegistryUnlocked(data);
    });
  }

  private async withLock<T>(action: () => Promise<T>): Promise<T> {
    const start = Date.now();
    await fs.mkdir(path.dirname(this.registryPath), { recursive: true });

    while (true) {
      try {
        const lockHandle = await fs.open(this.lockPath, 'wx');
        try {
          return await action();
        } finally {
          await lockHandle.close();
          await fs.rm(this.lockPath, { force: true });
        }
      } catch (error: any) {
        if (error?.code === 'ENOENT') {
          await fs.mkdir(path.dirname(this.registryPath), { recursive: true });
          continue;
        }

        if (error?.code !== 'EEXIST') {
          throw error;
        }

        const stale = await this.isLockStale();
        if (stale) {
          await fs.rm(this.lockPath, { force: true });
          continue;
        }

        if (Date.now() - start > LOCK_TIMEOUT_MS) {
          throw new Error(`Timeout acquiring instance registry lock: ${this.lockPath}`);
        }

        await sleep(25 + Math.floor(Math.random() * 25));
      }
    }
  }

  private async isLockStale(): Promise<boolean> {
    try {
      const stat = await fs.stat(this.lockPath);
      return Date.now() - stat.mtimeMs > LOCK_STALE_MS;
    } catch {
      return false;
    }
  }

  private async readRegistryUnlocked(): Promise<RegistryFileData> {
    try {
      const raw = await fs.readFile(this.registryPath, 'utf8');
      const parsed = JSON.parse(raw) as RegistryFileData;

      if (!parsed || typeof parsed !== 'object') {
        return createEmptyRegistry();
      }
      if (parsed.version !== 1) {
        return createEmptyRegistry();
      }
      if (!parsed.instances || typeof parsed.instances !== 'object') {
        return createEmptyRegistry();
      }

      return parsed;
    } catch (error: any) {
      if (error?.code === 'ENOENT') {
        return createEmptyRegistry();
      }
      return createEmptyRegistry();
    }
  }

  private async writeRegistryUnlocked(data: RegistryFileData): Promise<void> {
    const tmpPath = `${this.registryPath}.${process.pid}.${Date.now()}.tmp`;
    const text = `${JSON.stringify(data, null, 2)}\n`;

    await fs.writeFile(tmpPath, text, 'utf8');

    try {
      await fs.rename(tmpPath, this.registryPath);
    } catch (error: any) {
      if (error?.code === 'EEXIST' || error?.code === 'EPERM') {
        await fs.rm(this.registryPath, { force: true });
        await fs.rename(tmpPath, this.registryPath);
      } else {
        await fs.rm(tmpPath, { force: true });
        throw error;
      }
    }
  }

  private pruneStaleUnlocked(data: RegistryFileData, now: number): boolean {
    let changed = false;
    for (const [instanceId, entry] of Object.entries(data.instances)) {
      if (!entry?.lastSeenAt || now - entry.lastSeenAt > this.staleMs) {
        delete data.instances[instanceId];
        changed = true;
      }
    }
    return changed;
  }
}
