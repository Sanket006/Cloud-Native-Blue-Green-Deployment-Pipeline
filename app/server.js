const express = require('express');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

// The APP_VERSION environment variable will determine if this is blue or green.
const version = process.env.APP_VERSION || 'blue';
const podName = process.env.HOSTNAME || 'Unknown Pod';

app.use(express.static(path.join(__dirname, 'public')));

app.get('/api/info', (req, res) => {
    res.json({
        version: version,
        pod: podName,
        timestamp: new Date()
    });
});

app.listen(port, () => {
    console.log(`App deployed as [${version}] listening on port ${port}`);
});
