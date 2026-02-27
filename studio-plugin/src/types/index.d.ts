/// <reference types="@rbxts/types/plugin" />

export interface Connection {
	port: number;
	serverUrl: string;
	isActive: boolean;
	pollInterval: number;
	lastPoll: number;
	consecutiveFailures: number;
	maxFailuresBeforeError: number;
	lastSuccessfulConnection: number;
	currentRetryDelay: number;
	maxRetryDelay: number;
	retryBackoffMultiplier: number;
	lastHttpOk: boolean;
	mcpWaitStartTime?: number;
	isPolling: boolean;
	heartbeatConnection?: RBXScriptConnection;
	lastRegistryFetch: number;
	instanceId?: string;
	connectedPlaceName?: string;
	connectedPlaceId?: number;
	connectedGameId?: string;
	connectedJobId?: string;
}

export interface RequestData {
	[key: string]: unknown;
}

export interface RequestPayload {
	endpoint: string;
	data?: RequestData;
}

export interface PollResponse {
	mcpConnected: boolean;
	request?: RequestPayload;
	requestId?: string;
}

export interface PluginMetadata {
	placeName?: string;
	placeId?: number;
	gameId?: string;
	jobId?: string;
	updatedAt?: number;
}

export interface StatusResponse {
	pluginConnected: boolean;
	mcpServerActive: boolean;
	lastMCPActivity?: number;
	uptime?: number;
	instanceId?: string;
	host?: string;
	port?: number;
	pluginMetadata?: PluginMetadata;
}

export interface RegistryInstance {
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
	isCurrentContext?: boolean;
}

export interface RegistryInstancesResponse {
	currentInstanceId?: string;
	instances: RegistryInstance[];
}


declare global {
	function loadstring(code: string): LuaTuple<[(() => unknown) | undefined, string?]>;
}
