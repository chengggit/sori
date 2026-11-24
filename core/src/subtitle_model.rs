use crate::subtitles::{self, Cue};
use qtbridge::{qobject, QmlObject};
use serde::Deserialize;
use serde_json::{json, Value};
use std::path::Path;
use std::sync::Arc;

#[derive(Clone)]
struct Track {
    source: TrackSource,
    label: String,
}

#[derive(Clone)]
enum TrackSource {
    File { path: String, mapping: String },
    Text(Arc<str>),
}

#[derive(Default)]
struct Selection {
    index: i32,
    revision: u64,
    pending: bool,
    error: String,
    cues: Vec<Cue>,
}

pub struct Subtitles {
    generation: u64,
    attached: Option<usize>,
    tracks: Vec<Track>,
    slots: [Selection; 2],
    probing: bool,
    probe_error: String,
    transcript: Vec<Value>,
    starts: Vec<f64>,
    active_row: i32,
    primary_text: String,
    secondary_text: String,
    seconds: f64,
}

impl Default for Subtitles {
    fn default() -> Self {
        Self {
            generation: 0,
            attached: None,
            tracks: Vec::new(),
            slots: Default::default(),
            probing: false,
            probe_error: String::new(),
            transcript: Vec::new(),
            starts: Vec::new(),
            active_row: -1,
            primary_text: String::new(),
            secondary_text: String::new(),
            seconds: 0.0,
        }
    }
}

#[qobject(Singleton, ConvertToCamelCase)]
impl Subtitles {
    qproperty!("options", Read = options, Notify = tracks_changed);
    qproperty!("primary", Read = primary, Notify = tracks_changed);
    qproperty!("secondary", Read = secondary, Notify = tracks_changed);
    qproperty!("error", Read = error, Notify = tracks_changed);
    qproperty!("loading", Read = loading, Notify = tracks_changed);
    qproperty!(
        "primaryText",
        Member = primary_text,
        Notify = captions_changed
    );
    qproperty!(
        "secondaryText",
        Member = secondary_text,
        Notify = captions_changed
    );
    qproperty!(
        "transcript",
        Member = transcript,
        Notify = transcript_changed
    );
    qproperty!(
        "activeRow",
        Member = active_row,
        Notify = active_row_changed
    );

    #[qsignal]
    fn tracks_changed(&mut self);
    #[qsignal]
    fn captions_changed(&mut self);
    #[qsignal]
    fn transcript_changed(&mut self);
    #[qsignal]
    fn active_row_changed(&mut self);

    fn options(&self) -> Vec<String> {
        std::iter::once("Off".into())
            .chain(self.tracks.iter().map(|track| track.label.clone()))
            .collect()
    }

    fn primary(&self) -> i32 {
        self.slots[0].index
    }
    fn secondary(&self) -> i32 {
        self.slots[1].index
    }
    fn loading(&self) -> bool {
        self.probing || self.slots.iter().any(|slot| slot.pending)
    }

    fn error(&self) -> String {
        [
            &self.probe_error,
            &self.slots[0].error,
            &self.slots[1].error,
        ]
        .into_iter()
        .filter(|error| !error.is_empty())
        .cloned()
        .collect::<Vec<_>>()
        .join("\n")
    }

    #[qslot]
    fn reset(&mut self) {
        let generation = self.generation.wrapping_add(1);
        *self = Self {
            generation,
            ..Self::default()
        };
        self.transcript_changed();
        self.captions_changed();
        self.active_row_changed();
        self.tracks_changed();
    }

    #[qslot]
    fn probe(&mut self, path: String) {
        self.probing = true;
        self.tracks_changed();
        let generation = self.generation;
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = probe_tracks(&path);
            handle.invoke_mut(move |state| state.finish_probe(generation, result));
        });
    }

    #[qslot]
    fn select(&mut self, slot: i32, track: i32) {
        let slot = slot as usize;
        if slot >= self.slots.len()
            || track < 0
            || track as usize > self.tracks.len()
            || self.slots[slot].index == track
        {
            return;
        }
        if track != 0 && self.slots[1 - slot].index == track {
            self.load(1 - slot, 0);
        }
        self.load(slot, track);
        self.rebuild();
        self.tracks_changed();
    }

    #[qslot]
    fn attach(&mut self, path: String) {
        let path = Path::new(&path);
        let Some(resolved) = path.canonicalize().ok().filter(|file| file.is_file()) else {
            self.slots[0].error = "Choose a readable subtitle file.".into();
            self.tracks_changed();
            return;
        };
        self.attach_track(Track {
            source: TrackSource::File {
                path: resolved.to_string_lossy().into_owned(),
                mapping: "0:s:0".into(),
            },
            label: path
                .file_name()
                .unwrap_or_default()
                .to_string_lossy()
                .into_owned(),
        });
    }

    #[qslot]
    fn attach_saved(&mut self, text: String) {
        self.attach_track(Track {
            source: TrackSource::Text(text.into()),
            label: "Attached subtitles".into(),
        });
    }

    #[qslot]
    fn update(&mut self, time: f64) {
        self.seconds = time;
        let primary = active_text(&self.slots[0].cues, time);
        let secondary = active_text(&self.slots[1].cues, time);
        if self.primary_text != primary || self.secondary_text != secondary {
            self.primary_text = primary;
            self.secondary_text = secondary;
            self.captions_changed();
        }
        let row = self.starts.partition_point(|start| *start <= time) as i32 - 1;
        if self.active_row != row {
            self.active_row = row;
            self.active_row_changed();
        }
    }
}

impl Subtitles {
    fn attach_track(&mut self, source: Track) {
        let index = if let Some(index) = self.attached {
            self.tracks[index] = source;
            index
        } else {
            let index = self.tracks.len();
            self.tracks.push(source);
            self.attached = Some(index);
            index
        };
        let track = index as i32 + 1;
        if self.secondary() == track {
            self.load(1, 0);
        }
        self.load(0, track);
        self.rebuild();
        self.tracks_changed();
    }

    fn finish_probe(&mut self, generation: u64, result: Result<Vec<(Track, String)>, String>) {
        if self.generation != generation {
            return;
        }
        self.probing = false;
        let streams = match result {
            Ok(streams) => streams,
            Err(error) => {
                self.probe_error = error;
                self.tracks_changed();
                return;
            }
        };
        let first = self.tracks.len() as i32 + 1;
        let mut korean = 0;
        let mut english = 0;
        for (track, language) in streams {
            self.tracks.push(track);
            let index = self.tracks.len() as i32;
            match language.to_ascii_lowercase().split(['-', '_']).next() {
                Some("ko" | "kor") if korean == 0 => korean = index,
                Some("en" | "eng") if english == 0 => english = index,
                _ => {}
            }
        }
        if self.primary() == 0 {
            if korean != 0 {
                self.load(0, korean);
            } else if first <= self.tracks.len() as i32 && first != english {
                self.load(0, first);
            }
        }
        if english != 0 && self.secondary() == 0 && self.primary() != english {
            self.load(1, english);
        }
        self.tracks_changed();
    }

    fn load(&mut self, slot: usize, track: i32) {
        let revision = self.slots[slot].revision.wrapping_add(1);
        self.slots[slot] = Selection {
            index: track,
            revision,
            pending: track != 0,
            ..Selection::default()
        };
        if track == 0 {
            return;
        }
        let source = self.tracks[track as usize - 1].clone();
        let generation = self.generation;
        let handle = self.get_thread_handle();
        std::thread::spawn(move || {
            let result = extract(&source);
            handle.invoke_mut(move |state| {
                let selection = &mut state.slots[slot];
                if state.generation != generation || selection.revision != revision {
                    return;
                }
                selection.pending = false;
                match result {
                    Ok(cues) => selection.cues = cues,
                    Err(error) => selection.error = format!("{}: {error}", source.label),
                }
                state.rebuild();
                state.tracks_changed();
            });
        });
    }

    fn rebuild(&mut self) {
        let cues = &self.slots[0].cues;
        self.starts = cues.iter().map(|cue| cue.start).collect();
        self.transcript = cues
            .iter()
            .map(|cue| json!({ "start": cue.start, "end": cue.end, "text": cue.text }))
            .collect();
        self.transcript_changed();
        self.update(self.seconds);
    }
}

fn active_text(cues: &[Cue], seconds: f64) -> String {
    cues.iter()
        .take_while(|cue| cue.start <= seconds)
        .filter(|cue| seconds < cue.end)
        .map(|cue| cue.text.as_str())
        .collect::<Vec<_>>()
        .join("\n")
}

#[derive(Deserialize)]
struct Streams {
    #[serde(default)]
    streams: Vec<Stream>,
}

#[derive(Deserialize)]
struct Stream {
    index: u32,
    #[serde(default)]
    codec_name: String,
    #[serde(default)]
    tags: Tags,
}

#[derive(Default, Deserialize)]
struct Tags {
    #[serde(default)]
    language: String,
    #[serde(default)]
    title: String,
}

fn probe_tracks(path: &str) -> Result<Vec<(Track, String)>, String> {
    let output = subtitles::command_output(
        "ffprobe",
        [
            "-v",
            "error",
            "-protocol_whitelist",
            "file",
            "-select_streams",
            "s",
            "-show_entries",
            "stream=index,codec_name:stream_tags=language,title",
            "-of",
            "json",
            "-i",
            path,
        ],
        1024 * 1024,
    )?;
    let data: Streams =
        serde_json::from_slice(&output).map_err(|_| "Could not read embedded subtitle metadata")?;
    Ok(data
        .streams
        .into_iter()
        .filter(|stream| {
            matches!(
                stream.codec_name.as_str(),
                "subrip" | "ass" | "ssa" | "mov_text" | "webvtt" | "text"
            )
        })
        .map(|stream| {
            let id = stream.index.to_string();
            let label = [
                id.as_str(),
                &stream.tags.title,
                &stream.tags.language,
                &stream.codec_name,
            ]
            .into_iter()
            .filter(|part| !part.is_empty())
            .collect::<Vec<_>>()
            .join(" · ");
            (
                Track {
                    source: TrackSource::File {
                        path: path.into(),
                        mapping: format!("0:{id}"),
                    },
                    label,
                },
                stream.tags.language,
            )
        })
        .collect())
}

fn extract(source: &Track) -> Result<Vec<Cue>, String> {
    let output = match &source.source {
        TrackSource::Text(text) => return parse_cues(text),
        TrackSource::File { path, mapping } => subtitles::command_output(
            "ffmpeg",
            [
                "-v",
                "error",
                "-nostdin",
                "-protocol_whitelist",
                "file",
                "-i",
                path,
                "-map",
                mapping,
                "-c:s",
                "webvtt",
                "-f",
                "webvtt",
                "pipe:1",
            ],
            8 * 1024 * 1024,
        )?,
    };
    parse_cues(&String::from_utf8_lossy(&output))
}

fn parse_cues(text: &str) -> Result<Vec<Cue>, String> {
    let cues = subtitles::parse(text.trim_start_matches('\u{feff}'));
    if cues.is_empty() {
        Err("This track contains no readable subtitle cues".into())
    } else {
        Ok(cues)
    }
}
