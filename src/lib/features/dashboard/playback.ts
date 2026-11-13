type Player = {
  getCurrentTime(): number;
  getDuration(): number;
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

export function trackPlayback(
  frame: HTMLIFrameElement,
  save: (seconds: number, duration?: number) => void,
) {
  let player: Player | undefined;
  let timer: ReturnType<typeof setInterval> | undefined;
  let disposed = false;
  let playing = false;

  function record(target: Player) {
    const duration = target.getDuration();
    save(
      Math.floor(target.getCurrentTime()),
      Number.isFinite(duration) && duration > 0 ? duration : undefined,
    );
  }

  void loadPlayer()
    .then((Player) => {
      if (disposed) return;
      player = new Player(frame, {
        events: {
          onStateChange({ data, target }) {
            if (disposed) return;
            clearInterval(timer);
            playing = data === 1;
            if (playing || data === 2) record(target);
            if (playing) timer = setInterval(() => record(target), 2000);
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
      if (playing && player) record(player);
      player?.destroy();
    },
  };
}
export type Playback = {
  id: string;
  title: string;
  channel?: string;
  seconds: number;
  duration?: number;
};

export function formatPlaybackTime(seconds: number): string {
  const minutes = Math.floor(seconds / 60);
  const remainder = String(Math.floor(seconds % 60)).padStart(2, "0");
  if (minutes < 60) return `${minutes}:${remainder}`;
  return `${Math.floor(minutes / 60)}:${String(minutes % 60).padStart(2, "0")}:${remainder}`;
}

const historyKey = "sori-youtube-progress";

export function readProgress(): Playback | undefined {
  try {
    const saved = JSON.parse(localStorage.getItem(historyKey) ?? "null");
    if (
      saved &&
      /^[\w-]{11}$/.test(saved.id) &&
      typeof saved.title === "string" &&
      Number.isFinite(saved.seconds) &&
      saved.seconds > 0
    )
      return saved;
  } catch {
    // Playback remains available if storage is unavailable.
  }
}

export function saveProgress(video: Playback, seconds: number) {
  try {
    if (seconds > 0) localStorage.setItem(historyKey, JSON.stringify({ ...video, seconds }));
    else if (readProgress()?.id === video.id) localStorage.removeItem(historyKey);
  } catch {
    // Playback remains available if storage is unavailable.
  }
}
