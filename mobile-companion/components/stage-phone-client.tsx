"use client";

import { useEffect, useRef, useState } from "react";
import {
  applyStageMessage,
  parseStageSound,
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
import type { StampedPresentation } from "./stage-manager-puppet";

export function StagePhoneClient() {
  const [audioReady, setAudioReady] = useState(false);
  const unlockSound = useRef<(() => void) | null>(null);
  const [relay, setRelay] = useState<RelayStatus>("connecting");
  const [cues, setCues] = useState<StageChannels>(emptyStageChannels);
  const [presentation, setPresentation] = useState<StampedPresentation | null>({
    expression: "Default",
    talking: false,
    dialogueBoundary: false,
    sequence: 0,
  });

  useEffect(() => {
    const url = resolveStageRelayUrl(window.location.hash, window.location.hostname);
    const recipient = resolveStageRecipient(window.location.search);
    let channels = emptyStageChannels();
    let sequence = 0;
    let keepalive = 0;
    let context: AudioContext | null = null;
    let disposed = false;
    type SoundCommand = NonNullable<ReturnType<typeof parseStageSound>>;
    const active = new Map<string, AudioBufferSourceNode>();
    const versions = new Map<string, number>();
    const buffers = new Map<string, Promise<AudioBuffer>>();
    const lastIds = new Set<string>();
    let waitingSound: SoundCommand | null = null;
    const stopSound = (name: string) => {
      for (const sound of name === "all" ? ["tea", "suspense"] : [name]) {
        versions.set(sound, (versions.get(sound) ?? 0) + 1);
        active.get(sound)?.stop();
        active.delete(sound);
      }
      if (name === "all" || name === "tea") waitingSound = null;
    };
    const playSound = async (command: SoundCommand) => {
      if (command.action === "stop") { stopSound(command.sound); return; }
      if (command.sound === "tea") waitingSound = command;
      if (!context || context.state !== "running" || disposed) return;
      const audio = context;
      const version = (versions.get(command.sound) ?? 0) + 1;
      versions.set(command.sound, version);
      active.get(command.sound)?.stop();active.delete(command.sound);
      try {
        let buffer = buffers.get(command.sound);
        if (!buffer) {
          buffer = fetch(`/sound/${command.sound}.mp3`).then(r => {
            if (!r.ok) throw new Error("Phone sound unavailable");
            return r.arrayBuffer();
          }).then(data => audio.decodeAudioData(data));
          buffers.set(command.sound, buffer);
        }
        const decoded = await buffer;
        if (disposed || versions.get(command.sound) !== version) return;
        const source = audio.createBufferSource();source.buffer = decoded;
        source.loop = command.sound === "tea";
        const gain = audio.createGain();gain.gain.value = Math.pow(10, command.volumeDb / 20);
        source.connect(gain);gain.connect(audio.destination);
        source.onended = () => { if (active.get(command.sound) === source) active.delete(command.sound);source.disconnect();gain.disconnect(); };
        active.set(command.sound, source);source.start();
      } catch (error) { buffers.delete(command.sound);console.warn("Phone sound could not play", error); }
    };
    unlockSound.current = () => {
      context ??= new AudioContext();
      void context.resume().then(() => {
        if (disposed) return;
        setAudioReady(context?.state === "running");
        if (waitingSound) void playSound(waitingSound);
      });
    };

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
          stopSound("all");
          channels = emptyStageChannels();
          setCues(channels);
          sequence += 1;
          setPresentation({
            expression: "Default",
            talking: false,
            dialogueBoundary: true,
            sequence,
          });
        }
      },
      onMessage: (raw) => {
        let message: unknown;
        try {
          message = JSON.parse(raw);
        } catch {
          return;
        }
        const sound = parseStageSound(message);
        if (sound) {
          if (!lastIds.has(sound.requestId)) {
            lastIds.add(sound.requestId);
            if (lastIds.size > 100) lastIds.delete(lastIds.values().next().value!);
            void playSound(sound);
          }
          return;
        }
        const result = applyStageMessage(channels, message);
        if (result.state !== channels) {
          channels = result.state;
          setCues(channels);
        }
        if (result.presentation) {
          sequence += 1;
          setPresentation({ ...result.presentation, sequence });
        }
        if (result.ackRequestId) client.send(stageAck(result.ackRequestId));
      },
    });

    client.connect();
    return () => {
      disposed = true;unlockSound.current = null;stopSound("all");
      if (context) void context.close();
      clearKeepalive();
      client.disconnect();
    };
  }, []);

  return <>
    <StageFrame cues={cues} presentation={presentation} relay={relay} />
    {!audioReady && <button type="button" onClick={() => unlockSound.current?.()} style={{ position:"fixed", bottom:"max(12px, env(safe-area-inset-bottom))", right:12, zIndex:100, padding:"10px 16px", border:"1px solid #d7b9ef", borderRadius:8, background:"#21143c", color:"#fff", fontSize:16 }}>Enable phone sound</button>}
  </>;
}
