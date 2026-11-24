use libmpv2_sys::{
    mpv_render_param_type_MPV_RENDER_PARAM_API_TYPE as API_TYPE,
    mpv_render_param_type_MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME as BLOCK_FOR_TARGET_TIME,
    mpv_render_param_type_MPV_RENDER_PARAM_INVALID as END,
    mpv_render_param_type_MPV_RENDER_PARAM_OPENGL_FBO as OPENGL_FBO,
    mpv_render_param_type_MPV_RENDER_PARAM_OPENGL_INIT_PARAMS as OPENGL_INIT_PARAMS, *,
};
use std::ffi::{c_char, c_int, c_void};
use std::ptr::null_mut;

fn param(kind: mpv_render_param_type, data: *mut c_void) -> mpv_render_param {
    mpv_render_param { type_: kind, data }
}

// Qt calls these functions on its render thread with its OpenGL context current.
// The player and update callback data remain alive until the renderer is freed.
#[no_mangle]
pub unsafe extern "C" fn sori_mpv_renderer_create(
    context: *mut *mut mpv_render_context,
    player: *mut mpv_handle,
    resolve: unsafe extern "C" fn(*mut c_void, *const c_char) -> *mut c_void,
    display_kind: mpv_render_param_type,
    display: *mut c_void,
    request_frame: mpv_render_update_fn,
    callback_data: *mut c_void,
) -> c_int {
    let mut gl = mpv_opengl_init_params {
        get_proc_address: Some(resolve),
        get_proc_address_ctx: null_mut(),
    };
    let mut params = [
        param(
            API_TYPE,
            MPV_RENDER_API_TYPE_OPENGL.as_ptr().cast_mut().cast(),
        ),
        param(
            OPENGL_INIT_PARAMS,
            (&mut gl as *mut mpv_opengl_init_params).cast(),
        ),
        param(if display.is_null() { END } else { display_kind }, display),
        param(END, null_mut()),
    ];
    let status = mpv_render_context_create(context, player, params.as_mut_ptr());
    if status >= 0 {
        mpv_render_context_set_update_callback(*context, request_frame, callback_data);
    }
    status
}

#[no_mangle]
pub unsafe extern "C" fn sori_mpv_renderer_draw(
    context: *mut mpv_render_context,
    framebuffer: c_int,
    width: c_int,
    height: c_int,
    format: c_int,
) -> c_int {
    let mut target = mpv_opengl_fbo {
        fbo: framebuffer,
        w: width,
        h: height,
        internal_format: format,
    };
    let mut wait_for_target: c_int = 0;
    let mut params = [
        param(OPENGL_FBO, (&mut target as *mut mpv_opengl_fbo).cast()),
        param(
            BLOCK_FOR_TARGET_TIME,
            (&mut wait_for_target as *mut c_int).cast(),
        ),
        param(END, null_mut()),
    ];
    mpv_render_context_update(context);
    mpv_render_context_render(context, params.as_mut_ptr())
}

#[no_mangle]
pub unsafe extern "C" fn sori_mpv_renderer_free(context: *mut mpv_render_context) {
    mpv_render_context_set_update_callback(context, None, null_mut());
    mpv_render_context_free(context);
}

// On failure, leave the output handle null and return an mpv error code.
#[no_mangle]
pub unsafe extern "C" fn sori_mpv_player_create(output: *mut *mut mpv_handle) -> c_int {
    *output = null_mut();
    let player = mpv_create();
    if player.is_null() {
        return mpv_error_MPV_ERROR_NOMEM;
    }

    for (name, value) in [
        (c"vo", c"libmpv"),
        (c"keep-open", c"yes"),
        (c"sid", c"no"),
        (c"sub-auto", c"no"),
        (c"hwdec", c"auto,auto-copy-safe"),
        (c"video-timing-offset", c"0"),
        (c"terminal", c"yes"),
        (c"msg-level", c"statusline=no"),
    ] {
        mpv_set_option_string(player, name.as_ptr(), value.as_ptr());
    }

    let status = mpv_initialize(player);
    if status < 0 {
        mpv_destroy(player);
    } else {
        *output = player;
        controls::observe(player);
    }
    status
}

#[no_mangle]
pub unsafe extern "C" fn sori_mpv_player_free(player: *mut mpv_handle) {
    mpv_terminate_destroy(player);
}

mod analysis_model;
mod controls;
mod db;
mod dictionary;
mod krdict;
mod documents;
mod document_import;
mod library_model;
mod nlp;
mod progress;
mod process;
mod reader;
mod subtitles;
mod video_library;
mod video_transcript;
mod vocabulary;
mod youtube;
mod youtube_transcript;

mod player_model;
mod subtitle_model;

#[no_mangle]
pub extern "C" fn sori_qt_register_models() {
    use qtbridge::QmlElement;
    player_model::Player::register();
    subtitle_model::Subtitles::register();
    library_model::Library::register();
    analysis_model::Analysis::register();
    youtube::YouTube::register();
}
