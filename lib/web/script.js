let isPlaying = false;

function togglePlay() {
  const action = isPlaying ? 'pause' : 'play';
  controlPlayer(action);
}

function controlPlayer(action) {
  fetch(`/api/control?action=${action}`)
    .then(updatePlayerState);
}

function updatePlayerState() {
  fetch('/api/state')
    .then(response => response.json())
    .then(data => {
      document.getElementById('albumArt').style.backgroundImage = data.currentSong?.picture
        ? `url(/album-art?${Date.now()})`
        : 'none';
      document.getElementById('playPauseButton').textContent = isPlaying ? '⏸' : '▶';
      isPlaying = data.isPlaying;
    });
}

setInterval(updatePlayerState, 1000);
updatePlayerState();