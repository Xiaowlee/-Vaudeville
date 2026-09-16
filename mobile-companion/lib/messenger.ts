import { getRelayClient, sendRelayMessage } from "./websocket";

export type FaceCueMessage = {
  kind: "face_cue";
  cue: "smile";
  met: boolean;
  requestId?: string;
};

export type FacePresentMessage = {
  kind: "face_present";
  present: boolean;
  faceCount: number;
};

export type CompanionMessage = FaceCueMessage | FacePresentMessage;

export type MessageSender = (message: CompanionMessage) => void;

function defaultSender(message: CompanionMessage): void {
  const json = JSON.stringify(message);
  console.log("[companion]", json);
  sendRelayMessage(message);
}

let sendMessage: MessageSender = defaultSender;

export function setMessageSender(sender: MessageSender): void {
  sendMessage = sender;
}

export function sendCompanionMessage(message: CompanionMessage): void {
  sendMessage(message);
}

export function connectCompanionRelay(): void {
  getRelayClient().connect();
}
