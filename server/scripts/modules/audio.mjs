async function getAudioFiles() {
	try {
		const res = await fetch('/audiolisting');
		if (!res.ok) {
			throw new Error(`HTTP error. status: ${res.status}`);
		}
		let AUDIO_FILES_STRING = await res.text();
		AUDIO_FILES_STRING = AUDIO_FILES_STRING.replace(/'+/g, '');
		console.log('Audio listing:', AUDIO_FILES_STRING);
		return AUDIO_FILES_STRING;
	} catch (error) {
		console.error('Failed to fetch audio listing:', error);
	}

	return '';
}

const fisheryates = (arr) => {
	for (let i = arr.length - 1; i >= 0; i -= 1) {
		const temp = Math.floor(Math.random() * (i + 1));
		[arr[temp], arr[i]] = [arr[i], arr[temp]];
	}
	return arr;
};

const setupAudio = () => {
	getAudioFiles().then((data) => {
		if (!data || data.trim() === '') return;

		const AUDIO_FILES = fisheryates(data.split(',').filter((f) => f.trim() !== ''));
		if (AUDIO_FILES.length === 0) return;

		let index = 0;

		const audio = document.querySelector('#twcAudio');
		audio.src = AUDIO_FILES[index];

		audio.addEventListener('ended', () => {
			index = index > AUDIO_FILES.length ? 0 : index + 1;
			audio.src = AUDIO_FILES[index];
			audio.play();
		});
	});
};

setupAudio();
