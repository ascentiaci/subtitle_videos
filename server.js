const express = require('express');
const { spawn } = require('child_process');

const app = express();
const PORT = 3000;

app.use(express.json());

app.post('/run-container', (req, res) => {
    const { url } = req.body;

    if (!url) {
        return res.status(400).json({ error: "URL parameter is required" });
    }

    // Sanitize URL to prevent command injection
    const safeUrl = url.replace(/["'`;|&$<>]/g, '');

    // Docker compose command
    const command = `cd ~/ffmpeg && docker compose build && docker compose run --remove-orphans --rm whisper --url "${safeUrl}"`;

    // Run the command in the background using spawn
    const process = spawn(command, { shell: true, detached: true, stdio: 'ignore' });

    // Detach process so it runs independently
    process.unref();

    // Respond immediately
    res.json({ message: "Request Received. Processing in the background." });
});

app.listen(PORT, () => {
    console.log(`Server is running on http://localhost:${PORT}`);
});
