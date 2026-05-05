# QUVIAI — SketchUp Extension

Official SketchUp extension for [QUVIAI](https://quvi.ai). Captures your active viewport and transforms it into a photorealistic architectural render using the QUVIAI AI API. Also supports AI-powered 3D object generation directly into your scene.

## Requirements

- SketchUp Pro 2021 or newer
- A [QUVIAI account](https://quvi.ai)

## Installation

### From a release (recommended)

1. Download the latest `quviai_sketchup.rbz` from [Releases](https://github.com/quvi-ai/sketchup-plugin/releases)
2. In SketchUp: **Window → Extension Manager → Install Extension…**
3. Select the downloaded `.rbz` — do **not** unzip it
4. Open the panel: **Plugins → QUVIAI → Open Panel**
5. Log in with your QUVIAI credentials

### Building from source

```bash
git clone https://github.com/quvi-ai/sketchup-plugin.git
cd sketchup-plugin
bash scripts/build_rbz.sh
```

Then install the generated `quviai_sketchup.rbz` as above.

## Logging in

Open the panel via **Plugins → QUVIAI → Open Panel** and enter your QUVIAI email and password. Your session is saved automatically — you won't need to log in again on the next launch.

## Usage

### Render 3D

1. Set up your scene in SketchUp
2. Open the QUVIAI panel (**Plugins → QUVIAI → Open Panel**)
3. Choose a **Category** (Architectural or General) and **Style**
4. Enter a **Prompt** describing the scene
5. Configure **Render Type**, **Time of Day**, and **Weather** (Architectural only)
6. Make sure **Use current viewport as reference** is checked
7. Click **Render** — the result opens automatically when complete

### 3D Object Generation

1. Switch to **From Prompt** or **From Image** mode in the 3D Object section
2. Enter a prompt or select an image file
3. Click **Generate 3D Object** — the GLB is imported directly into your scene

## Render parameters

| Parameter | Description | Example values |
|-----------|-------------|----------------|
| Category | Architectural or general/illustration | Architectural, General |
| Style | Visual style applied to the render | Modern, Art Deco, Futuristic … |
| Prompt | Text description of the scene | "modern office lobby with plants" |
| Render Type | Type of architectural render | Exterior, Interior, Site |
| Time of Day | Lighting preset | Day, Night |
| Weather | Atmosphere preset | Sunny, Cloudy, Rainy, Snowy … |

## Error messages

| Message | Cause | Fix |
|---------|-------|-----|
| Not logged in | No session saved | Log in via the panel |
| Insufficient credits | Account balance is 0 | Top up at [quvi.ai](https://quvi.ai/pricing) |
| Session expired | Token expired | Log out and log in again |
| GLB import failed | SketchUp version too old | Use SketchUp Pro 2021 or newer |

## Contributing

Pull requests are welcome. All contributions require a review before merging — see [CODEOWNERS](.github/CODEOWNERS).

## License

MIT — see [LICENSE](LICENSE).
