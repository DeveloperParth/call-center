import { type Server as HttpServer } from "http";
import { Server } from "socket.io";
import { InternalSocketServer } from "./types";

let io: InternalSocketServer;
export const setupSocket = (server: HttpServer) => {
  io = new Server(server);
};
