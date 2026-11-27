import type { PlaybackEvents } from "../video/playback";

type Player = {
  getCurrentTime(): number;
  getDuration(): number;
  destroy(): void;
  playVideo(): void;
  pauseVideo(): void;
  seekTo(seconds: number, allowSeekAhead: boolean): void;
};

type PlayerConstructor = new (
  frame: HTMLIFrameElement,
  options: {
    events: {
      onReady(event: { target: Player }): void;
      onStateChange(event: { data: number; target: Player }): void;
    };
  },
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

/** Track an embedded YouTube player and report time/checkpoints through events. */
export function trackPlayback(frame: HTMLIFrameElement, events: PlaybackEvents) {
  let player: Player | undefined;
  let timer: ReturnType<typeof setInterval> | undefined;
  let disposed = false;
  let playing = false;

  function record(target: Player, completed = false) {
    const duration = target.getDuration();
    events.onTime(target.getCurrentTime());
    events.onSave(
      Math.floor(target.getCurrentTime()),
      Number.isFinite(duration) && duration > 0 ? duration : undefined,
      completed,
    );
  }

  void loadPlayer()
    .then((Player) => {
      if (disposed) return;
      player = new Player(frame, {
        events: {
          onReady({ target }) {
            if (disposed) return;
            events.onControls({
              play: () => target.playVideo(),
              pause: () => target.pauseVideo(),
              seek: (seconds) => target.seekTo(seconds, true),
            });
          },
          onStateChange({ data, target }) {
            if (disposed) return;
            clearInterval(timer);
            playing = data === 1;
            if (playing || data === 2) record(target);
            if (playing) {
              let ticks = 0;
              timer = setInterval(() => {
                if (++ticks % 8 === 0) record(target);
                else events.onTime(target.getCurrentTime());
              }, 250);
            }
            if (data === 0) record(target, true);
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
      events.onControls(undefined);
      player?.destroy();
    },
  };
}
