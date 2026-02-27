import path from 'path';
import { promises as fs } from 'fs';
import { InstanceRegistry } from '../instance-registry';

describe('InstanceRegistry', () => {
  let registryPath: string;
  let registryDir: string;

  beforeEach(() => {
    const stamp = `${Date.now()}-${Math.floor(Math.random() * 1_000_000)}`;
    registryDir = path.join(process.cwd(), '.tmp-registry-tests', stamp);
    registryPath = path.join(registryDir, 'instances.json');
  });

  afterEach(async () => {
    await fs.rm(registryDir, { recursive: true, force: true });
  });

  test('should register and list instances sorted by port', async () => {
    const registry = new InstanceRegistry({ registryPath, staleMs: 60_000 });

    await registry.registerInstance({
      instanceId: 'b',
      pid: 12,
      host: '127.0.0.1',
      port: 58742,
      startedAt: Date.now(),
      lastSeenAt: Date.now(),
      mcpServerActive: true,
      pluginConnected: false,
      lastPluginActivity: 0,
    });

    await registry.registerInstance({
      instanceId: 'a',
      pid: 11,
      host: '127.0.0.1',
      port: 58741,
      startedAt: Date.now(),
      lastSeenAt: Date.now(),
      mcpServerActive: true,
      pluginConnected: true,
      lastPluginActivity: Date.now(),
    });

    const instances = await registry.listInstances();
    expect(instances.map((it) => it.instanceId)).toEqual(['a', 'b']);
    expect(instances.map((it) => it.port)).toEqual([58741, 58742]);
  });

  test('should update metadata and heartbeat', async () => {
    const registry = new InstanceRegistry({ registryPath, staleMs: 60_000 });
    await registry.registerInstance({
      instanceId: 'x',
      pid: 25,
      host: '127.0.0.1',
      port: 58750,
      startedAt: Date.now(),
      lastSeenAt: Date.now(),
      mcpServerActive: false,
      pluginConnected: false,
      lastPluginActivity: 0,
    });

    await registry.heartbeat('x', {
      mcpServerActive: true,
      pluginConnected: true,
      lastPluginActivity: Date.now(),
      pluginMetadata: {
        placeName: 'Arena',
        placeId: 123,
        gameId: 'gid',
        jobId: 'jid',
        updatedAt: Date.now(),
      },
    });

    const current = await registry.getInstance('x');
    expect(current?.mcpServerActive).toBe(true);
    expect(current?.pluginConnected).toBe(true);
    expect(current?.pluginMetadata?.placeName).toBe('Arena');
    expect(current?.pluginMetadata?.placeId).toBe(123);
  });

  test('should cleanup stale instances during reads', async () => {
    const registry = new InstanceRegistry({ registryPath, staleMs: 10 });
    await registry.registerInstance({
      instanceId: 'stale',
      pid: 99,
      host: '127.0.0.1',
      port: 58760,
      startedAt: Date.now() - 1000,
      lastSeenAt: Date.now() - 1000,
      mcpServerActive: false,
      pluginConnected: false,
      lastPluginActivity: 0,
    });

    const instances = await registry.listInstances();
    expect(instances).toHaveLength(0);
    expect(await registry.getInstance('stale')).toBeNull();
  });
});

