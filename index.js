// express
const express = require('express');

const app = express();
const port = process.env.WS4KP_PORT ?? 8080;
const path = require('path');

// template engine
app.set('view engine', 'ejs');

// cors pass through
const fs = require('fs');
const corsPassThru = require('./cors');
const radarPassThru = require('./cors/radar');
const outlookPassThru = require('./cors/outlook');

// cors pass-thru to api.weather.gov
app.get('/stations/*', corsPassThru);
app.get('/Conus/*', radarPassThru);
app.get('/products/*', outlookPassThru);

// route for audio files: scan local directory or fall back to env var
const audioDir = process.env.AUDIO_DIR || '';
const audioFilesString = process.env.AUDIO_FILES ?? '';

// serve local audio files if AUDIO_DIR is configured
if (audioDir && fs.existsSync(audioDir)) {
	app.use('/audio/local', express.static(audioDir));
}

app.get('/audiolisting', (req, res) => {
	// if a local audio directory is configured, scan it for audio files
	if (audioDir && fs.existsSync(audioDir)) {
		const audioExtensions = ['.mp3', '.ogg', '.m4a', '.wav', '.aac', '.flac'];
		try {
			const files = fs.readdirSync(audioDir)
				.filter((f) => audioExtensions.includes(path.extname(f).toLowerCase()))
				.sort()
				.map((f) => `/audio/local/${encodeURIComponent(f)}`);
			res.send(files.join(','));
			return;
		} catch (e) {
			console.error('Error scanning audio directory:', e.message);
		}
	}
	// fall back to AUDIO_FILES env var (cloud URLs)
	res.send(audioFilesString);
});

// kiosk mode configuration
const kioskZip = process.env.KIOSK_ZIPCODE || '';
app.get('/kiosk-config', (req, res) => {
	res.json({
		enabled: process.env.KIOSK_MODE === '1',
		zipCode: kioskZip,
	});
});

// version
const { version } = JSON.parse(fs.readFileSync('package.json'));

const index = (req, res) => {
	res.render(path.join(__dirname, 'views/index'), {
		production: false,
		version,
	});
};

// debugging
if (process.env?.DIST === '1') {
	// distribution
	app.use('/audio', express.static(path.join(__dirname, './server/audio')));
	app.use('/images', express.static(path.join(__dirname, './server/images')));
	app.use('/fonts', express.static(path.join(__dirname, './server/fonts')));
	app.use('/scripts', express.static(path.join(__dirname, './server/scripts')));
	app.use('/', express.static(path.join(__dirname, './dist')));
} else {
	// debugging
	app.get('/index.html', index);
	app.get('/', index);
	app.get('*', express.static(path.join(__dirname, './server')));
}

const server = app.listen(port, () => {
	console.log(`Server listening on port ${port}`);
});

// graceful shutdown
process.on('SIGINT', () => {
	server.close(() => {
		console.log('Server closed');
	});
});
