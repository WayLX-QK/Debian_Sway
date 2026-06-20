-- record.lua  —  Enhanced mpv recording script

local mp    = require 'mp'
local opts  = {
  output_dir          = "~/Videos/Recordings",
  record_all_streams  = true,  -- default: yes (record all). In script-opts use "yes"/"no".
  ffmpeg_base_cmd     = 'ffmpeg -i "%s" %s -c copy -f mpegts "%s" & echo $!',
}

-- Load options via mp.options from ~/.config/mpv/script-opts/record.conf
require 'mp.options'.read_options(opts, "record")

-- Debug: log the mode
mp.msg.info(string.format("[record] record_all_streams = %s", tostring(opts.record_all_streams)))

-- Expand "~" and env vars
local function expand(path)
  path = path:gsub("^~", os.getenv("HOME"))
  return path:gsub("%$([%w_]+)", os.getenv)
end

-- Ensure output directory exists
local outdir = expand(opts.output_dir)
os.execute(('mkdir -p "%s"'):format(outdir))

-- Sanitize filenames
local function sanitize(str)
  return (str:gsub("[<>:\"/\\|%?%%*]", "_"):gsub("%s+", "_"))
end

-- Format time
local function format_time(sec)
  return os.date("%H-%M-%S", math.floor(sec or 0))
end

-- Build output path
local function get_output_path()
  local title = sanitize(mp.get_property("media-title") or "unknown")
  local date  = os.date("%Y-%m-%d_%H-%M-%S")
  local pos   = mp.get_property_number("time-pos") or 0
  return string.format("%s/MPV-%s-%s-%s.ts", outdir, title, date, format_time(pos))
end

-- Build -map args
local function build_map_args()
  if opts.record_all_streams then
    return "-map 0"
  else
    -- get selected track IDs
    local aid = mp.get_property_number("aid")
    local sid = mp.get_property_number("sid")
    -- iterate track-list to find ordinals
    local audio_count, subtitle_count = 0, 0
    local sel_audio_ord, sel_sub_ord = nil, nil
    for _, t in ipairs(mp.get_property_native("track-list") or {}) do
      if t.type == "audio" then
        if t.id == aid then sel_audio_ord = audio_count end
        audio_count = audio_count + 1
      elseif t.type == "sub" then
        if t.id == sid then sel_sub_ord = subtitle_count end
        subtitle_count = subtitle_count + 1
      end
    end
    -- map video stream
    local parts = {"-map 0:v:0"}
    -- map selected audio or fallback
    if sel_audio_ord then
      table.insert(parts, string.format("-map 0:a:%d", sel_audio_ord))
    else
      mp.osd_message("⚠️ No selected audio found, recording all audio")
      table.insert(parts, "-map 0:a")
    end
    -- map selected subtitle if exists
    if sel_sub_ord then
      table.insert(parts, string.format("-map 0:s:%d", sel_sub_ord))
    elseif sid and sid ~= nil then
      mp.osd_message("⚠️ No selected subtitle found, skipping subtitles")
    end
    return table.concat(parts, " ")
  end
end

-- Recording state
local recording = false
local ffmpeg_pid = nil

-- Toggle record
local function toggle_record()
  if recording then
    if ffmpeg_pid then os.execute("kill "..ffmpeg_pid); ffmpeg_pid = nil end
    recording = false
    return mp.osd_message("🛑 Recording stopped")
  end
  local path = mp.get_property("path")
  if not path then return mp.osd_message("❌ No input to record") end
  local outfile = get_output_path()
  mp.osd_message("📁 "..outfile)
  local maps = build_map_args()
  local cmd  = string.format(opts.ffmpeg_base_cmd, path, maps, outfile)
  mp.osd_message("⚙️ "..cmd)
  local pipe = io.popen(cmd)
  ffmpeg_pid = pipe:read("*n"); pipe:close()
  recording = true
  mp.osd_message("⏺️ Recording started")
end

-- Clean up
mp.register_event("shutdown", function()
  if recording and ffmpeg_pid then os.execute("kill "..ffmpeg_pid) end
end)

-- Key binding: press 'r' to toggle
mp.add_key_binding("r", "toggle-record", toggle_record)
