import esl from "modesl";

console.log("Connecting to FreeSWITCH ESL...");
const client = new esl.Connection("13.204.143.72", 8021, "ClueCon", () => {
  console.log("Connected to FreeSWITCH ESL");
  client.api("status", (res) => {
    console.log("FreeSWITCH status:", res.getBody());
  });
});

client.on("error", (err) => {
  console.error("Error connecting to FreeSWITCH ESL:", err);
});
