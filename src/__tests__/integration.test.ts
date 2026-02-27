import request from 'supertest';
import { createHttpServer } from '../http-server';
import { RobloxStudioTools } from '../tools/index';
import { BridgeService } from '../bridge-service';
import { Application } from 'express';
import path from 'path';
import { promises as fs } from 'fs';
import { InstanceRegistry } from '../instance-registry';

describe('Integration Tests', () => {
  let app: Application & any;
  let bridge: BridgeService;
  let tools: RobloxStudioTools;

  beforeEach(() => {
    bridge = new BridgeService();
    tools = new RobloxStudioTools(bridge);
    app = createHttpServer(tools, bridge);
  });

  afterEach(() => {

    bridge.clearAllPendingRequests();
  });

  describe('Full Connection Flow', () => {
    test('should handle complete connection lifecycle', async () => {

      let status = await request(app).get('/status').expect(200);
      expect(status.body.pluginConnected).toBe(false);
      expect(status.body.mcpServerActive).toBe(false);

      await request(app).post('/ready').expect(200);

      status = await request(app).get('/status').expect(200);
      expect(status.body.pluginConnected).toBe(true);
      expect(status.body.mcpServerActive).toBe(false);

      let pollResponse = await request(app).get('/poll').expect(503);
      expect(pollResponse.body).toMatchObject({
        error: 'MCP server not connected',
        pluginConnected: true,
        mcpConnected: false
      });

      app.setMCPServerActive(true);

      status = await request(app).get('/status').expect(200);
      expect(status.body.pluginConnected).toBe(true);
      expect(status.body.mcpServerActive).toBe(true);

      pollResponse = await request(app).get('/poll').expect(200);
      expect(pollResponse.body).toMatchObject({
        request: null,
        mcpConnected: true,
        pluginConnected: true
      });

      await request(app).post('/disconnect').expect(200);

      status = await request(app).get('/status').expect(200);
      expect(status.body.pluginConnected).toBe(false);
      expect(status.body.mcpServerActive).toBe(true);
    });
  });

  describe('Request/Response Flow', () => {
    test('should handle complete request/response cycle', async () => {

      await request(app).post('/ready').expect(200);
      app.setMCPServerActive(true);

      const mcpRequestPromise = bridge.sendRequest('/api/test-endpoint', {
        testData: 'hello',
        value: 123
      });

      const pollResponse = await request(app).get('/poll').expect(200);
      expect(pollResponse.body.request).toMatchObject({
        endpoint: '/api/test-endpoint',
        data: {
          testData: 'hello',
          value: 123
        }
      });
      const requestId = pollResponse.body.requestId;

      await request(app)
        .post('/response')
        .send({
          requestId: requestId,
          response: {
            success: true,
            result: 'processed',
            echo: 'hello'
          }
        })
        .expect(200);

      const mcpResponse = await mcpRequestPromise;
      expect(mcpResponse).toEqual({
        success: true,
        result: 'processed',
        echo: 'hello'
      });
    });

    test('should handle error responses', async () => {

      await request(app).post('/ready').expect(200);
      app.setMCPServerActive(true);

      const mcpRequestPromise = bridge.sendRequest('/api/failing-endpoint', {});
      mcpRequestPromise.catch(() => {});

      const pollResponse = await request(app).get('/poll').expect(200);
      const requestId = pollResponse.body.requestId;

      await request(app)
        .post('/response')
        .send({
          requestId: requestId,
          error: 'Operation failed: Invalid input'
        })
        .expect(200);

      await expect(mcpRequestPromise).rejects.toEqual('Operation failed: Invalid input');
    });
  });

  describe('Disconnect Recovery', () => {
    test('should handle disconnect and reconnect gracefully', async () => {

      await request(app).post('/ready').expect(200);
      app.setMCPServerActive(true);

      const request1 = bridge.sendRequest('/api/test1', {});
      const request2 = bridge.sendRequest('/api/test2', {});
      request1.catch(() => {});
      request2.catch(() => {});

      let poll = await request(app).get('/poll').expect(200);
      expect(poll.body.request).toBeTruthy();

      await request(app).post('/disconnect').expect(200);

      await expect(request1).rejects.toThrow('Connection closed');
      await expect(request2).rejects.toThrow('Connection closed');

      await request(app).post('/ready').expect(200);

      const newRequestPromise = bridge.sendRequest('/api/test3', {});

      poll = await request(app).get('/poll').expect(200);
      expect(poll.body.request?.endpoint).toBe('/api/test3');

      await request(app)
        .post('/response')
        .send({
          requestId: poll.body.requestId,
          response: { success: true }
        })
        .expect(200);

      const result = await newRequestPromise;
      expect(result).toEqual({ success: true });
    });
  });

  describe('Connection State Display', () => {
    test('should show correct pending states during connection', async () => {

      let health = await request(app).get('/health').expect(200);
      expect(health.body.pluginConnected).toBe(false);
      expect(health.body.mcpServerActive).toBe(false);

      await request(app).get('/poll').expect(503);

      health = await request(app).get('/health').expect(200);
      expect(health.body.pluginConnected).toBe(true);
      expect(health.body.mcpServerActive).toBe(false);

      app.setMCPServerActive(true);

      const poll = await request(app).get('/poll').expect(200);
      expect(poll.body.mcpConnected).toBe(true);
      expect(poll.body.pluginConnected).toBe(true);
    });
  });

  describe('Timeout Handling', () => {
    test('should handle request timeouts', async () => {
      jest.useFakeTimers();

      await request(app).post('/ready').expect(200);
      app.setMCPServerActive(true);

      const timeoutPromise = bridge.sendRequest('/api/slow-endpoint', {});

      await request(app).get('/poll').expect(200);

      jest.advanceTimersByTime(31000);

      await expect(timeoutPromise).rejects.toThrow('Request timeout');

      jest.useRealTimers();
    });
  });

  describe('Multi-instance Registry Visibility', () => {
    test('should show multiple running servers and attached place metadata', async () => {
      const stamp = `${Date.now()}-${Math.floor(Math.random() * 1_000_000)}`;
      const registryDir = path.join(process.cwd(), '.tmp-integration-registry-tests', stamp);
      const registryPath = path.join(registryDir, 'instances.json');
      const sharedRegistry = new InstanceRegistry({ registryPath, staleMs: 60_000 });

      const idA = 'instance-A';
      const idB = 'instance-B';
      await sharedRegistry.registerInstance({
        instanceId: idA,
        pid: process.pid,
        host: '127.0.0.1',
        port: 58741,
        startedAt: Date.now(),
        lastSeenAt: Date.now(),
        mcpServerActive: true,
        pluginConnected: false,
        lastPluginActivity: 0,
      });
      await sharedRegistry.registerInstance({
        instanceId: idB,
        pid: process.pid,
        host: '127.0.0.1',
        port: 58742,
        startedAt: Date.now(),
        lastSeenAt: Date.now(),
        mcpServerActive: true,
        pluginConnected: false,
        lastPluginActivity: 0,
      });

      const appA = createHttpServer(tools, bridge, {
        instanceId: idA,
        host: '127.0.0.1',
        port: 58741,
        registry: sharedRegistry,
      }) as Application & any;
      const appB = createHttpServer(tools, bridge, {
        instanceId: idB,
        host: '127.0.0.1',
        port: 58742,
        registry: sharedRegistry,
      }) as Application & any;

      appA.setMCPServerActive(true);
      appB.setMCPServerActive(true);

      await request(appA)
        .post('/ready')
        .send({
          placeName: 'Place-A',
          placeId: 101,
          gameId: 'game-a',
          jobId: 'job-a',
        })
        .expect(200);

      const listFromB = await request(appB)
        .get('/registry/instances')
        .expect(200);

      const ports = listFromB.body.instances.map((inst: any) => inst.port);
      expect(ports).toContain(58741);
      expect(ports).toContain(58742);

      const placeA = listFromB.body.instances.find((inst: any) => inst.port === 58741);
      expect(placeA.pluginMetadata.placeName).toBe('Place-A');
      expect(placeA.pluginMetadata.placeId).toBe(101);

      const currentA = await request(appA)
        .get('/registry/current')
        .expect(200);
      expect(currentA.body.instance.instanceId).toBe(idA);

      await fs.rm(registryDir, { recursive: true, force: true });
    });
  });
});
