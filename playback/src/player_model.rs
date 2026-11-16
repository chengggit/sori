use crate::controls::{self, EventKind};
use libmpv2_sys::*;
use qtbridge::qobject;
use std::ffi::{c_char, c_void, CStr, CString};
use std::path::Path;
use std::sync::atomic::{AtomicPtr, Ordering};

static HANDLE: AtomicPtr<mpv_handle> = AtomicPtr::new(std::ptr::null_mut());

#[no_mangle]
pub extern "C" fn sori_qt_start() -> i32 {
    let mut handle = std::ptr::null_mut();
    let result = unsafe { crate::sori_mpv_player_create(&mut handle) };
    HANDLE.store(handle, Ordering::Release);
    result
}

#[no_mangle]
pub extern "C" fn sori_qt_handle() -> *mut mpv_handle {
    HANDLE.load(Ordering::Acquire)
}

#[no_mangle]
pub extern "C" fn sori_qt_stop() {
    let handle = HANDLE.swap(std::ptr::null_mut(), Ordering::AcqRel);
    if !handle.is_null() {
        unsafe { crate::sori_mpv_player_free(handle) };
    }
}

#[derive(Default)]
pub struct Player {
    ready: bool,
    loaded: bool,
    loading: bool,
    paused: bool,
    ended: bool,
    duration: f64,
    position: f64,
    filename: String,
    error: String,
    details: String,
    audio_tracks: Vec<String>,
    audio_ids: Vec<String>,
    audio_index: i32,
    dropped: i32,
    decoder: String,
    codec: String,
    container: String,
    file_path: String,
    pending_path: String,
}

#[qobject(Singleton, ConvertToCamelCase)]
impl Player {
    qproperty!("ready", Member = ready, Notify = state_changed);
    qproperty!("loaded", Member = loaded, Notify = state_changed);
    qproperty!("loading", Member = loading, Notify = state_changed);
    qproperty!("paused", Member = paused, Notify = state_changed);
    qproperty!("ended", Member = ended, Notify = state_changed);
    qproperty!("duration", Member = duration, Notify = state_changed);
    qproperty!("position", Member = position, Notify = position_changed);
    qproperty!("filename", Member = filename, Notify = state_changed);
    qproperty!("error", Member = error, Notify = state_changed);
    qproperty!("details", Member = details, Notify = state_changed);
    qproperty!("audioTracks", Member = audio_tracks, Notify = state_changed);
    qproperty!("audioIndex", Member = audio_index, Notify = state_changed);
    qproperty!("dropped", Member = dropped, Notify = state_changed);

    #[qsignal]
    fn state_changed(&mut self);
    #[qsignal]
    fn position_changed(&mut self);
    #[qsignal]
    fn media_opening(&mut self);
    #[qsignal]
    fn media_ready(&mut self, path: &String);

    #[qslot]
    fn renderer_ready(&mut self, ready: bool) {
        self.ready = ready;
        if ready && !self.pending_path.is_empty() {
            let path = std::mem::take(&mut self.pending_path);
            self.open(path);
        }
        self.state_changed();
    }

    #[qslot]
    fn renderer_failed(&mut self, result: i32) {
        self.loading = false;
        self.error = format!("Video renderer failed: {}", error_message(result));
        self.state_changed();
    }

    #[qslot]
    fn open(&mut self, path: String) {
        if self.loading || sori_qt_handle().is_null() {
            return;
        }
        if !self.ready {
            self.pending_path = path;
            return;
        }
        let file = Path::new(&path);
        let resolved = file.canonicalize().ok().filter(|local| local.is_file());
        let handle_path = resolved
            .as_ref()
            .and_then(|local| CString::new(local.to_str()?).ok());
        let Some(handle_path) = handle_path else {
            self.error = "Choose a readable local video file.".into();
            self.state_changed();
            return;
        };
        self.media_opening();
        self.file_path = handle_path.to_string_lossy().into_owned();
        self.filename = file
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .into_owned();
        self.loaded = false;
        self.loading = true;
        self.paused = false;
        self.ended = false;
        self.error.clear();
        self.details.clear();
        self.decoder.clear();
        self.codec.clear();
        self.container.clear();
        self.audio_ids.clear();
        self.audio_tracks.clear();
        self.audio_index = -1;
        self.dropped = 0;
        self.position = 0.0;
        self.duration = 0.0;
        let result = unsafe { controls::sori_mpv_load(sori_qt_handle(), handle_path.as_ptr()) };
        if result < 0 {
            self.loading = false;
            self.error = error_message(result);
        }
        self.state_changed();
        self.position_changed();
    }

    #[qslot]
    fn toggle_play(&self) {
        if self.loaded {
            unsafe { controls::sori_mpv_toggle(sori_qt_handle(), self.ended) };
        }
    }

    #[qslot]
    fn seek(&self, position: f64) {
        if self.loaded {
            unsafe { controls::sori_mpv_seek(sori_qt_handle(), position, self.duration) };
        }
    }

    #[qslot]
    fn volume(&self, value: f64) {
        let handle = sori_qt_handle();
        if !handle.is_null() {
            unsafe { controls::sori_mpv_volume(handle, value) };
        }
    }

    #[qslot]
    fn select_audio(&self, index: i32) {
        if let Some(id) = self
            .audio_ids
            .get(index as usize)
            .and_then(|id| CString::new(id.as_str()).ok())
        {
            unsafe { controls::sori_mpv_select_audio(sori_qt_handle(), id.as_ptr()) };
        }
    }

    #[qslot]
    fn format_time(&self, position: f64) -> String {
        let total = position.max(0.0) as u64;
        let (minutes, seconds) = (total / 60, total % 60);
        if total >= 3600 {
            format!("{}:{:02}:{seconds:02}", total / 3600, minutes % 60)
        } else {
            format!("{minutes}:{seconds:02}")
        }
    }

    #[qslot]
    fn poll(&mut self) {
        let handle = sori_qt_handle();
        if handle.is_null() {
            return;
        }
        let mut update = Update {
            player: self,
            state: false,
            position: false,
            loaded: false,
        };
        unsafe { controls::sori_mpv_drain(handle, receive, (&mut update as *mut Update).cast()) };
        let Update {
            state,
            position,
            loaded,
            ..
        } = update;
        if state {
            self.state_changed();
        }
        if position {
            self.position_changed();
        }
        if loaded && self.loaded {
            self.media_ready(&self.file_path.clone());
        }
    }
}

struct Update<'a> {
    player: &'a mut Player,
    state: bool,
    position: bool,
    loaded: bool,
}

unsafe extern "C" fn receive(context: *mut c_void, kind: EventKind, data: *const c_void) {
    let update = &mut *context.cast::<Update>();
    let player = &mut update.player;
    match kind {
        EventKind::Time => {
            player.position = *data.cast::<f64>();
            update.position = true;
            return;
        }
        EventKind::Duration => player.duration = *data.cast::<f64>(),
        EventKind::Pause => player.paused = *data.cast::<i32>() != 0,
        EventKind::Eof => player.ended = *data.cast::<i32>() != 0,
        EventKind::Audio => {
            let selected = mpv_text(*data.cast::<*const c_char>());
            player.audio_index = player
                .audio_ids
                .iter()
                .position(|id| id == &selected)
                .map_or(-1, |index| index as i32);
        }
        EventKind::Decoder => {
            player.decoder = mpv_text(*data.cast::<*const c_char>());
            player.update_details();
        }
        EventKind::Drops => player.dropped = *data.cast::<i64>() as i32,
        EventKind::Loaded => {
            player.loading = false;
            player.loaded = true;
            player.read_metadata();
            update.loaded = true;
        }
        EventKind::PlaybackError | EventKind::LoadError => {
            player.loading = false;
            if matches!(kind, EventKind::PlaybackError) {
                player.loaded = false;
                player.error = format!("Playback failed: {}", mpv_text(data.cast()));
            } else {
                player.error = mpv_text(data.cast());
            }
        }
    }
    update.state = true;
}

impl Player {
    fn update_details(&mut self) {
        if !self.loaded {
            return;
        }
        let decoder = if self.decoder.is_empty() || self.decoder == "no" {
            "Software decode".into()
        } else {
            format!("Hardware decode ({})", self.decoder)
        };
        self.details = [&self.container, &self.codec, &decoder]
            .into_iter()
            .filter(|value| !value.is_empty())
            .cloned()
            .collect::<Vec<_>>()
            .join("  ·  ");
    }

    fn read_metadata(&mut self) {
        let handle = sori_qt_handle();
        self.codec = property(handle, c"video-format");
        self.container = property(handle, c"file-format");
        self.update_details();

        let mut count: i64 = 0;
        unsafe {
            mpv_get_property(
                handle,
                c"track-list/count".as_ptr(),
                mpv_format_MPV_FORMAT_INT64,
                (&mut count as *mut i64).cast(),
            )
        };
        for index in 0..count {
            let read = |key| {
                property(
                    handle,
                    &CString::new(format!("track-list/{index}/{key}")).unwrap(),
                )
            };
            if read("type") != "audio" {
                continue;
            }
            let id = read("id");
            let label = [id.clone(), read("lang"), read("title"), read("codec")]
                .into_iter()
                .filter(|value| !value.is_empty())
                .collect::<Vec<_>>()
                .join(" · ");
            self.audio_ids.push(id);
            self.audio_tracks.push(label);
        }
        let selected = property(handle, c"aid");
        self.audio_index = self
            .audio_ids
            .iter()
            .position(|id| id == &selected)
            .map_or(-1, |index| index as i32);
    }
}

fn property(handle: *mut mpv_handle, name: &CStr) -> String {
    unsafe {
        let value = mpv_get_property_string(handle, name.as_ptr());
        let result = mpv_text(value);
        mpv_free(value.cast());
        result
    }
}

fn error_message(code: i32) -> String {
    unsafe { mpv_text(mpv_error_string(code)) }
}

unsafe fn mpv_text(value: *const c_char) -> String {
    if value.is_null() {
        return String::new();
    }
    CStr::from_ptr(value).to_string_lossy().into_owned()
}
