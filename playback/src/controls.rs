use libmpv2_sys::{
    mpv_event_id_MPV_EVENT_COMMAND_REPLY as EVENT_COMMAND_REPLY,
    mpv_event_id_MPV_EVENT_END_FILE as EVENT_END_FILE,
    mpv_event_id_MPV_EVENT_FILE_LOADED as EVENT_FILE_LOADED,
    mpv_event_id_MPV_EVENT_NONE as EVENT_NONE,
    mpv_event_id_MPV_EVENT_PROPERTY_CHANGE as EVENT_PROPERTY_CHANGE, *,
};
use std::ffi::{c_char, c_int, c_void, CStr, CString};
use std::ptr;

const LOAD_REPLY: u64 = 1;

// The caller keeps the handle and any C string arguments alive for these calls.
unsafe fn command<const N: usize>(player: *mut mpv_handle, reply: u64, args: [&CStr; N]) -> c_int {
    let mut values = [ptr::null(); 4];
    assert!(N < values.len());
    for (out, arg) in values.iter_mut().zip(args) {
        *out = arg.as_ptr();
    }
    mpv_command_async(player, reply, values.as_mut_ptr())
}

#[no_mangle]
pub unsafe extern "C" fn sori_mpv_load(player: *mut mpv_handle, path: *const c_char) -> c_int {
    command(player, 0, [c"set", c"aid", c"auto"]);
    command(player, 0, [c"set", c"pause", c"no"]);
    command(
        player,
        LOAD_REPLY,
        [c"loadfile", CStr::from_ptr(path), c"replace"],
    )
}

#[no_mangle]
pub unsafe extern "C" fn sori_mpv_toggle(player: *mut mpv_handle, ended: bool) {
    if ended {
        sori_mpv_seek(player, 0.0, 0.0);
        command(player, 0, [c"set", c"pause", c"no"]);
    } else {
        command(player, 0, [c"cycle", c"pause"]);
    }
}

#[no_mangle]
pub unsafe extern "C" fn sori_mpv_seek(player: *mut mpv_handle, seconds: f64, duration: f64) {
    if seconds.is_finite() {
        let position = CString::new(seconds.max(0.0).min(duration.max(0.0)).to_string()).unwrap();
        command(player, 0, [c"seek", &position, c"absolute+exact"]);
    }
}

#[no_mangle]
pub unsafe extern "C" fn sori_mpv_volume(player: *mut mpv_handle, value: f64) {
    if value.is_finite() {
        let volume = CString::new(value.clamp(0.0, 100.0).to_string()).unwrap();
        command(player, 0, [c"set", c"volume", &volume]);
    }
}

#[no_mangle]
pub unsafe extern "C" fn sori_mpv_select_audio(player: *mut mpv_handle, id: *const c_char) {
    command(player, 0, [c"set", c"aid", CStr::from_ptr(id)]);
}

#[repr(u32)]
#[derive(Clone, Copy)]
pub enum EventKind {
    Time = 1,
    Duration,
    Pause,
    Eof,
    Audio,
    Decoder,
    Drops,
    Loaded,
    PlaybackError,
    LoadError,
}

const PROPERTIES: [(EventKind, &CStr, mpv_format); 7] = [
    (EventKind::Time, c"time-pos", mpv_format_MPV_FORMAT_DOUBLE),
    (
        EventKind::Duration,
        c"duration",
        mpv_format_MPV_FORMAT_DOUBLE,
    ),
    (EventKind::Pause, c"pause", mpv_format_MPV_FORMAT_FLAG),
    (EventKind::Eof, c"eof-reached", mpv_format_MPV_FORMAT_FLAG),
    (EventKind::Audio, c"aid", mpv_format_MPV_FORMAT_STRING),
    (
        EventKind::Decoder,
        c"hwdec-current",
        mpv_format_MPV_FORMAT_STRING,
    ),
    (
        EventKind::Drops,
        c"frame-drop-count",
        mpv_format_MPV_FORMAT_INT64,
    ),
];

pub(super) unsafe fn observe(player: *mut mpv_handle) {
    for (kind, name, format) in PROPERTIES {
        mpv_observe_property(player, kind as u64, name.as_ptr(), format);
    }
}

// Callback arguments borrow the event data only until the callback returns.
#[no_mangle]
pub unsafe extern "C" fn sori_mpv_drain(
    player: *mut mpv_handle,
    receive: unsafe extern "C" fn(*mut c_void, EventKind, *const c_void),
    receiver: *mut c_void,
) {
    loop {
        let event = &*mpv_wait_event(player, 0.0);
        let (kind, data) = match event.event_id {
            EVENT_NONE => break,
            EVENT_FILE_LOADED => (EventKind::Loaded, ptr::null()),
            EVENT_END_FILE => {
                let end = &*event.data.cast::<mpv_event_end_file>();
                if end.reason != mpv_end_file_reason_MPV_END_FILE_REASON_ERROR {
                    continue;
                }
                (EventKind::PlaybackError, mpv_error_string(end.error).cast())
            }
            EVENT_COMMAND_REPLY if event.reply_userdata == LOAD_REPLY && event.error < 0 => {
                (EventKind::LoadError, mpv_error_string(event.error).cast())
            }
            EVENT_PROPERTY_CHANGE => {
                let change = &*event.data.cast::<mpv_event_property>();
                let Some(&(kind, _, format)) = event
                    .reply_userdata
                    .checked_sub(1)
                    .and_then(|index| PROPERTIES.get(index as usize))
                else {
                    continue;
                };
                if change.data.is_null() || change.format != format {
                    continue;
                }
                (kind, change.data.cast_const())
            }
            _ => continue,
        };
        receive(receiver, kind, data);
    }
}
