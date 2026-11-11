import type { Socket, DefaultEventsMap, Server } from "socket.io";
type SocketData = {
  user: {
    id: string;
  };
};
export type InternalSocket = Socket<
  DefaultEventsMap,
  DefaultEventsMap,
  DefaultEventsMap,
  SocketData
>;

export type InternalSocketServer = Server<
  DefaultEventsMap,
  DefaultEventsMap,
  DefaultEventsMap,
  SocketData
>;
