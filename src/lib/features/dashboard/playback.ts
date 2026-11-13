type Player = {
  getCurrentTime(): number;
  destroy(): void;
};

type PlayerConstructor = new (
  frame: HTMLIFrameElement,
  options: { events: { onStateChange(event: { data: number; target: Player }): void } },
) => Player;

let api: Promise<PlayerConstructor> | undefined;

function loadPlayer() {
  const youtube = window as Window & {
    YT?: { Player?: PlayerConstructor };
    onYouTubeIframeAPIReady?: () => void;
  };
  if (youtube.YT?.Player) return Promise.resolve(youtube.YT.Player);
  api ??= new Promise<PlayerConstructor>((resolve, reject) => {
    const script = document.createElement("script");
    youtube.onYouTubeIframeAPIReady = () => {
      if (youtube.YT?.Player) resolve(youtube.YT.Player);
      else reject(new Error("YouTube player unavailable"));
    };
    script.onerror = () => {
      script.remove();
      reject(new Error("YouTube player unavailable"));
    };
    script.src = "https://www.youtube.com/iframe_api";
    document.head.append(script);
  }).catch((error) => {
    api = undefined;
    throw error;
  });
  return api;
}

export function trackPlayback(frame: HTMLIFrameElement, save: (seconds: number) => void) {
  let player: Player | undefined;
  let timer: ReturnType<typeof setInterval> | undefined;
  let disposed = false;
  let playing = false;

  void loadPlayer()
    .then((Player) => {
      if (disposed) return;
      player = new Player(frame, {
        events: {
          onStateChange({ data, target }) {
            if (disposed) return;
            clearInterval(timer);
            playing = data === 1;
            if (playing || data === 2) save(Math.floor(target.getCurrentTime()));
            if (playing) timer = setInterval(() => save(Math.floor(target.getCurrentTime())), 2000);
            if (data === 0) save(0);
          },
        },
      });
    })
    .catch(() => {
      // The iframe can still play if the API script is unavailable.
    });

  return {
    destroy() {
      disposed = true;
      clearInterval(timer);
      if (playing && player) save(Math.floor(player.getCurrentTime()));
      player?.destroy();
    },
  };
}
