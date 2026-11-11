import express from "express";
import { createServer } from "http";
import { setupSocket } from "./lib/socket";
const app = express();

const httpServer = createServer(app);
setupSocket(httpServer);
