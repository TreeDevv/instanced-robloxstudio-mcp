import express from 'express';
import cors from 'cors';
import { RobloxStudioTools } from './tools/index.js';
import { BridgeService } from './bridge-service.js';
import { InstanceRegistry, InstanceRegistryEntry, PluginMetadata } from './instance-registry.js';

export interface HttpServerContext {
  instanceId: string;
  host: string;
  port: number;
  registry: InstanceRegistry;
}

interface CurrentContextSnapshot {
  instanceId: string | null;
  host: string | null;
  port: number | null;
  pluginConnected: boolean;
  mcpServerActive: boolean;
  pluginMetadata: PluginMetadata | null;
}

export function createHttpServer(
  tools: RobloxStudioTools,
  bridge: BridgeService,
  context?: HttpServerContext
) {
  const app = express();
  let pluginConnected = false;
  let mcpServerActive = false;
  let lastMCPActivity = 0;
  let mcpServerStartTime = 0;
  let lastPluginActivity = 0;
  let pluginMetadata: PluginMetadata | undefined;
  let binding = context
    ? {
      instanceId: context.instanceId,
      host: context.host,
      port: context.port,
    }
    : null;

  const parsePluginMetadata = (body: any): PluginMetadata | undefined => {
    if (!body || typeof body !== 'object') {
      return undefined;
    }

    const metadata: PluginMetadata = {
      updatedAt: Date.now(),
    };

    if (typeof body.placeName === 'string' && body.placeName.length > 0) {
      metadata.placeName = body.placeName;
    }
    if (typeof body.placeId === 'number' && Number.isFinite(body.placeId)) {
      metadata.placeId = body.placeId;
    }
    if (typeof body.gameId === 'string' && body.gameId.length > 0) {
      metadata.gameId = body.gameId;
    }
    if (typeof body.jobId === 'string' && body.jobId.length > 0) {
      metadata.jobId = body.jobId;
    }

    if (!metadata.placeName && metadata.placeId === undefined && !metadata.gameId && !metadata.jobId) {
      return undefined;
    }

    return metadata;
  };

  const getCurrentContextSnapshot = (): CurrentContextSnapshot => ({
    instanceId: binding?.instanceId ?? null,
    host: binding?.host ?? null,
    port: binding?.port ?? null,
    pluginConnected: isPluginConnected(),
    mcpServerActive: isMCPServerActive(),
    pluginMetadata: pluginMetadata ?? null,
  });

  const syncRegistryState = async () => {
    if (!context?.registry || !binding) {
      return;
    }

    await context.registry.heartbeat(binding.instanceId, {
      pid: process.pid,
      host: binding.host,
      port: binding.port,
      mcpServerActive: isMCPServerActive(),
      pluginConnected: isPluginConnected(),
      lastPluginActivity,
      pluginMetadata: pluginMetadata ?? null,
    });
  };


  const setMCPServerActive = (active: boolean) => {
    mcpServerActive = active;
    if (active) {
      mcpServerStartTime = Date.now();
      lastMCPActivity = Date.now();
    } else {
      mcpServerStartTime = 0;
      lastMCPActivity = 0;
    }
    void syncRegistryState();
  };

  const trackMCPActivity = () => {
    if (mcpServerActive) {
      lastMCPActivity = Date.now();
    }
    void syncRegistryState();
  };

  const isMCPServerActive = () => {
    if (!mcpServerActive) return false;
    const now = Date.now();
    const mcpRecent = (now - lastMCPActivity) < 15000;
    return mcpRecent;
  };

  const isPluginConnected = () => {

    return pluginConnected && (Date.now() - lastPluginActivity < 10000);
  };

  app.use(cors());
  app.use(express.json({ limit: '50mb' }));
  app.use(express.urlencoded({ limit: '50mb', extended: true }));


  app.get('/health', (req, res) => {
    res.json({
      status: 'ok',
      service: 'robloxstudio-mcp',
      pluginConnected,
      mcpServerActive: isMCPServerActive(),
      uptime: mcpServerActive ? Date.now() - mcpServerStartTime : 0,
      instanceId: binding?.instanceId ?? null,
      host: binding?.host ?? null,
      port: binding?.port ?? null,
      currentContext: getCurrentContextSnapshot(),
    });
  });


  app.post('/ready', async (req, res) => {
    try {
      bridge.clearAllPendingRequests();
      pluginConnected = true;
      lastPluginActivity = Date.now();
      pluginMetadata = parsePluginMetadata(req.body);

      await syncRegistryState();
      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/disconnect', async (req, res) => {
    try {
      pluginConnected = false;
      pluginMetadata = undefined;

      bridge.clearAllPendingRequests();
      await syncRegistryState();
      res.json({ success: true });
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.get('/status', (req, res) => {
    res.json({
      pluginConnected: isPluginConnected(),
      mcpServerActive: isMCPServerActive(),
      lastMCPActivity,
      uptime: mcpServerActive ? Date.now() - mcpServerStartTime : 0,
      instanceId: binding?.instanceId ?? null,
      host: binding?.host ?? null,
      port: binding?.port ?? null,
      pluginMetadata: pluginMetadata ?? null,
      currentContext: getCurrentContextSnapshot(),
    });
  });

  app.get('/registry/instances', async (req, res) => {
    try {
      if (!context?.registry) {
        const currentContext = getCurrentContextSnapshot();
        const fallbackInstance = currentContext.instanceId
          ? [{
            ...currentContext,
            startedAt: 0,
            lastSeenAt: Date.now(),
            pid: process.pid,
            lastPluginActivity,
            isCurrentContext: true,
          }]
          : [];

        res.json({
          currentInstanceId: currentContext.instanceId,
          instances: fallbackInstance,
        });
        return;
      }

      const instances = await context.registry.listInstances();
      const payload = instances.map((instance) => ({
        ...instance,
        isCurrentContext: instance.instanceId === binding?.instanceId,
      }));

      res.json({
        currentInstanceId: binding?.instanceId ?? null,
        instances: payload,
      });
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.get('/registry/current', async (req, res) => {
    try {
      if (!context?.registry || !binding) {
        res.json({
          instance: getCurrentContextSnapshot(),
        });
        return;
      }

      const current = await context.registry.getInstance(binding.instanceId);
      const snapshot: InstanceRegistryEntry | CurrentContextSnapshot = current ?? getCurrentContextSnapshot();

      res.json({
        instance: snapshot,
        isCurrentContext: true,
      });
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.get('/poll', (req, res) => {

    if (!pluginConnected) {
      pluginConnected = true;
    }
    lastPluginActivity = Date.now();
    void syncRegistryState();

    if (!isMCPServerActive()) {
      res.status(503).json({
        error: 'MCP server not connected',
        pluginConnected: true,
        mcpConnected: false,
        request: null
      });
      return;
    }

    const pendingRequest = bridge.getPendingRequest();
    if (pendingRequest) {
      res.json({
        request: pendingRequest.request,
        requestId: pendingRequest.requestId,
        mcpConnected: true,
        pluginConnected: true
      });
    } else {
      res.json({
        request: null,
        mcpConnected: true,
        pluginConnected: true
      });
    }
  });


  app.post('/response', (req, res) => {
    const { requestId, response, error } = req.body;

    if (error) {
      bridge.rejectRequest(requestId, error);
    } else {
      bridge.resolveRequest(requestId, response);
    }

    res.json({ success: true });
  });



  app.use('/mcp/*', (req, res, next) => {
    trackMCPActivity();
    next();
  });


  app.post('/mcp/get_file_tree', async (req, res) => {
    try {
      const result = await tools.getFileTree(req.body.path);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/search_files', async (req, res) => {
    try {
      const result = await tools.searchFiles(req.body.query, req.body.searchType);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/get_place_info', async (req, res) => {
    try {
      const result = await tools.getPlaceInfo();
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/get_services', async (req, res) => {
    try {
      const result = await tools.getServices(req.body.serviceName);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/search_objects', async (req, res) => {
    try {
      const result = await tools.searchObjects(req.body.query, req.body.searchType, req.body.propertyName);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/get_instance_properties', async (req, res) => {
    try {
      const result = await tools.getInstanceProperties(req.body.instancePath);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/get_instance_children', async (req, res) => {
    try {
      const result = await tools.getInstanceChildren(req.body.instancePath);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/search_by_property', async (req, res) => {
    try {
      const result = await tools.searchByProperty(req.body.propertyName, req.body.propertyValue);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/get_class_info', async (req, res) => {
    try {
      const result = await tools.getClassInfo(req.body.className);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/mass_set_property', async (req, res) => {
    try {
      const result = await tools.massSetProperty(req.body.paths, req.body.propertyName, req.body.propertyValue);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/mass_get_property', async (req, res) => {
    try {
      const result = await tools.massGetProperty(req.body.paths, req.body.propertyName);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/create_object_with_properties', async (req, res) => {
    try {
      const result = await tools.createObjectWithProperties(req.body.className, req.body.parent, req.body.name, req.body.properties);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/mass_create_objects', async (req, res) => {
    try {
      const result = await tools.massCreateObjects(req.body.objects);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/mass_create_objects_with_properties', async (req, res) => {
    try {
      const result = await tools.massCreateObjectsWithProperties(req.body.objects);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/get_project_structure', async (req, res) => {
    try {
      const result = await tools.getProjectStructure(req.body.path, req.body.maxDepth, req.body.scriptsOnly);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/get_script_source', async (req, res) => {
    try {
      const result = await tools.getScriptSource(req.body.instancePath);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/set_script_source', async (req, res) => {
    try {
      const result = await tools.setScriptSource(req.body.instancePath, req.body.source);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/get_selection', async (req, res) => {
    try {
      const result = await tools.getSelection();
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/execute_luau', async (req, res) => {
    try {
      const result = await tools.executeLuau(req.body.code);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/set_property', async (req, res) => {
    try {
      const result = await tools.setProperty(req.body.instancePath, req.body.propertyName, req.body.propertyValue);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/create_object', async (req, res) => {
    try {
      const result = await tools.createObject(req.body.className, req.body.parent, req.body.name);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/delete_object', async (req, res) => {
    try {
      const result = await tools.deleteObject(req.body.instancePath);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/smart_duplicate', async (req, res) => {
    try {
      const result = await tools.smartDuplicate(req.body.instancePath, req.body.count, req.body.options);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/mass_duplicate', async (req, res) => {
    try {
      const result = await tools.massDuplicate(req.body.duplications);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/set_calculated_property', async (req, res) => {
    try {
      const result = await tools.setCalculatedProperty(req.body.paths, req.body.propertyName, req.body.formula, req.body.variables);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/set_relative_property', async (req, res) => {
    try {
      const result = await tools.setRelativeProperty(req.body.paths, req.body.propertyName, req.body.operation, req.body.value, req.body.component);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/edit_script_lines', async (req, res) => {
    try {
      const result = await tools.editScriptLines(req.body.instancePath, req.body.startLine, req.body.endLine, req.body.newContent);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/insert_script_lines', async (req, res) => {
    try {
      const result = await tools.insertScriptLines(req.body.instancePath, req.body.afterLine, req.body.newContent);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/delete_script_lines', async (req, res) => {
    try {
      const result = await tools.deleteScriptLines(req.body.instancePath, req.body.startLine, req.body.endLine);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/get_attribute', async (req, res) => {
    try {
      const result = await tools.getAttribute(req.body.instancePath, req.body.attributeName);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/set_attribute', async (req, res) => {
    try {
      const result = await tools.setAttribute(req.body.instancePath, req.body.attributeName, req.body.attributeValue, req.body.valueType);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/get_attributes', async (req, res) => {
    try {
      const result = await tools.getAttributes(req.body.instancePath);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/delete_attribute', async (req, res) => {
    try {
      const result = await tools.deleteAttribute(req.body.instancePath, req.body.attributeName);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/get_tags', async (req, res) => {
    try {
      const result = await tools.getTags(req.body.instancePath);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/add_tag', async (req, res) => {
    try {
      const result = await tools.addTag(req.body.instancePath, req.body.tagName);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/remove_tag', async (req, res) => {
    try {
      const result = await tools.removeTag(req.body.instancePath, req.body.tagName);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/get_tagged', async (req, res) => {
    try {
      const result = await tools.getTagged(req.body.tagName);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  app.post('/mcp/start_playtest', async (req, res) => {
    try {
      const result = await tools.startPlaytest(req.body.mode);
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/stop_playtest', async (req, res) => {
    try {
      const result = await tools.stopPlaytest();
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });

  app.post('/mcp/get_playtest_output', async (req, res) => {
    try {
      const result = await tools.getPlaytestOutput();
      res.json(result);
    } catch (error) {
      res.status(500).json({ error: error instanceof Error ? error.message : 'Unknown error' });
    }
  });


  (app as any).isPluginConnected = isPluginConnected;
  (app as any).setMCPServerActive = setMCPServerActive;
  (app as any).isMCPServerActive = isMCPServerActive;
  (app as any).trackMCPActivity = trackMCPActivity;
  (app as any).getCurrentContext = getCurrentContextSnapshot;
  (app as any).setInstanceBinding = (nextBinding: { instanceId: string; host: string; port: number }) => {
    binding = {
      instanceId: nextBinding.instanceId,
      host: nextBinding.host,
      port: nextBinding.port,
    };
    void syncRegistryState();
  };

  return app;
}
