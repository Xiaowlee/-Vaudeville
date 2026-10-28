"use client";

import { useEffect, useState } from "react";
import {
  applyStageMessage,
  emptyStageChannels,
  resolveStageRecipient,
  resolveStageRelayUrl,
  STAGE_KEEPALIVE_MS,
  STAGE_RECONNECT_MS,
  stageAck,
  stageHello,
  stageKeepalive,
  type StageChannels,
} from "../lib/stage-phone";
import { createRelayClient, type RelayStatus } from "../lib/websocket";
import { StageFrame } from "./stage-frame";

export function StagePhoneClient() {
  const [relay, setRelay] = useState<RelayStatus>("connecting");
  const [cues, setCues] = useState<StageChannels>(emptyStageChannels);

  useEffect(() => {
    const url = resolveStageRelayUrl(window.location.hash, window.location.hostname);
    const recipient = resolveStageRecipient(window.location.search);
    let channels = emptyStageChannels();
    let keepalive = 0;

    const clearKeepalive = () => {
      if (keepalive) window.clearInterval(keepalive);
      keepalive = 0;
    };

    const client = createRelayClient({
      url,
      reconnectMs: STAGE_RECONNECT_MS,
      onStatus: (status) => {
        setRelay(status);
        if (status === "open") {
          client.send(stageHello(recipient));
          clearKeepalive();
          keepalive = window.setInterval(() => {
            client.send(stageKeepalive());
          }, STAGE_KEEPALIVE_MS);
          return;
        }
        clearKeepalive();
        if (status === "closed" || status === "error") {
          channels = emptyStageChannels();
          setCues(channels);
        }
      },
      onMessage: (raw) => {
        let message: unknown;
        try {
          message = JSON.parse(raw);
        } catch {
          return;
        }
        const result = applyStageMessage(channels, message);
        if (result.state !== channels) {
          channels = result.state;
          setCues(channels);
        }
        if (result.ackRequestId) client.send(stageAck(result.ackRequestId));
      },
    });

    client.connect();
    return () => {
      clearKeepalive();
      client.disconnect();
    };
  }, []);

  return <StageFrame cues={cues} relay={relay} />;
}
