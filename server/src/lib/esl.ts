import esl from "modesl";

let connection: esl.Connection | null = null;
let connectingPromise: Promise<esl.Connection> | null = null;
function connect(timeoutMs = 5000) {
  if (connectingPromise) return connectingPromise;
  if (connection?.connected()) return Promise.resolve(connection);

  connectingPromise = new Promise((resolve, reject) => {
    let settled = false;

    const timer = setTimeout(() => {
      if (!settled) {
        settled = true;
        connectingPromise = null;
        reject(new Error(`ESL connection timed out after ${timeoutMs}ms`));
      }
    }, timeoutMs);

    const client = new esl.Connection("13.204.143.72", 8021, "ClueCon", () => {
      if (settled) {
        client.disconnect();
        return;
      }
      settled = true;
      clearTimeout(timer);
      connection = client;
      connectingPromise = null;
      console.log("Connected to FreeSWITCH ESL");
      resolve(client);
    });

    client.on("error", (err) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      connectingPromise = null;
      console.error("Error connecting to FreeSWITCH ESL:", err);
      reject(err);
    });
  });

  return connectingPromise;
}
