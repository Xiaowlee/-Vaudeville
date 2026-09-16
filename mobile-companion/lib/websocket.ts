export type RelayStatus = "idle" | "connecting" | "open" | "closed" | "error";

export type RelayClientOptions = {
  url?: string;
  reconnectMs?: number;
  onStatus?: (status: RelayStatus) => void;
  onMessage?: (data: string) => void;
};

export type RelayClient = {
  connect: () => void;
  disconnect: () => void;
  send: (payload: unknown) => boolean;
  getStatus: () => RelayStatus;
  getUrl: () => string;
};

export function getRelayUrl(): string {
  const configured = process.env.NEXT_PUBLIC_RELAY_URL?.trim() ?? "";
  if (!configured || typeof window === "undefined") {
    return configured;
  }

  try {
    const url = new URL(configured);
    const pageHost = window.location.hostname;
    const relayIsLocal = url.hostname === "localhost" || url.hostname === "127.0.0.1";
    const pageIsLocal = pageHost === "localhost" || pageHost === "127.0.0.1";
    if (relayIsLocal && !pageIsLocal) {
      url.hostname = pageHost;
    }
    return url.toString();
  } catch {
    return configured;
  }
}

export function createRelayClient(options: RelayClientOptions = {}): RelayClient {
  const url = options.url?.trim() || getRelayUrl();
  const reconnectMs = options.reconnectMs ?? 2000;

  let socket: WebSocket | null = null;
  let status: RelayStatus = "idle";
  let shouldReconnect = false;
  let reconnectTimer = 0;

  function setStatus(next: RelayStatus): void {
    status = next;
    options.onStatus?.(next);
    for (const listener of statusListeners) {
      listener(next);
    }
  }

  function clearReconnect(): void {
    if (reconnectTimer) {
      window.clearTimeout(reconnectTimer);
      reconnectTimer = 0;
    }
  }

  function scheduleReconnect(): void {
    if (!shouldReconnect || !url || reconnectTimer) {
      return;
    }
    reconnectTimer = window.setTimeout(() => {
      reconnectTimer = 0;
      connect();
    }, reconnectMs);
  }

  function connect(): void {
    if (!url || typeof WebSocket === "undefined") {
      setStatus("idle");
      return;
    }
    if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) {
      return;
    }

    shouldReconnect = true;
    clearReconnect();
    setStatus("connecting");

    try {
      socket = new WebSocket(url);
    } catch (error) {
      console.warn("[relay] failed to open", error);
      setStatus("error");
      scheduleReconnect();
      return;
    }

    socket.addEventListener("open", () => {
      setStatus("open");
    });

    socket.addEventListener("message", (event) => {
      if (typeof event.data === "string") {
        options.onMessage?.(event.data);
        for (const listener of messageListeners) listener(event.data);
      }
    });

    socket.addEventListener("close", () => {
      socket = null;
      setStatus("closed");
      scheduleReconnect();
    });

    socket.addEventListener("error", () => {
      setStatus("error");
    });
  }

  function disconnect(): void {
    shouldReconnect = false;
    clearReconnect();
    if (socket) {
      socket.close();
      socket = null;
    }
    setStatus("closed");
  }

  function send(payload: unknown): boolean {
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      return false;
    }
    socket.send(typeof payload === "string" ? payload : JSON.stringify(payload));
    return true;
  }

  return {
    connect,
    disconnect,
    send,
    getStatus: () => status,
    getUrl: () => url,
  };
}

type StatusListener = (status: RelayStatus) => void;
const statusListeners = new Set<StatusListener>();

let sharedClient: RelayClient | null = null;

export function subscribeRelayStatus(listener: StatusListener): () => void {
  statusListeners.add(listener);
  listener(sharedClient?.getStatus() ?? "idle");
  return () => {
    statusListeners.delete(listener);
  };
}

export function relayStatusLabel(status: RelayStatus): string {
  return status === "open" ? "connected" : status;
}

export function getRelayClient(): RelayClient {
  if (!sharedClient) {
    sharedClient = createRelayClient();
  }
  return sharedClient;
}

export function sendRelayMessage(payload: unknown): boolean {
  return getRelayClient().send(payload);
}

const messageListeners = new Set<(data: string) => void>();
export function subscribeRelayMessages(listener: (data: string) => void): () => void {
  messageListeners.add(listener);
  return () => { messageListeners.delete(listener); };
}
