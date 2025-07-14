# Arrbit – Automated Arr Scripts for Lidarr 🎶🤖

Arrbit is a lightweight, modular toolkit to auto‑configure and extend your Lidarr setup. Point it at your `/config` folder and it will:

- Install community plugins (Tidal, Deezer, Tubifarry…) 🔌  
- Auto‑configure media paths, metadata, UI settings, naming rules, and more 🤖  
- Load your own custom scripts & formats ✨  
- Manage download delays & quality profiles


---

## ⚙️ What Each Script/Module Does

| Emoji | Script / Module               | Description                                              |
|:-----:|:------------------------------|:---------------------------------------------------------|
| 🏷️    | **ArrbitTagger.bash**         | Tags new albums in Beets                                 |
| 🔧    | **functions.bash**            | Shared helper functions                                  |
| 🍐    | **beets-config.yaml**         | Beets import settings                                    |
| 🎶    | **genre-whitelist.txt**       | List of allowed genres                                   |
| 🔌    | **plugins_add.bash**          | Installs community plugins (Tidal/Deezer/etc.)           |
| 🤖    | **autoconfig.bash**           | Runs each module based on your flags                     |
| 📂    | **media_management.bash**     | Sets up file paths & import behavior                     |
| 📡    | **metadata_consumer.bash**    | Configures metadata consumers (Plex/Kodi/etc.)           |
| ✍️    | **metadata_write.bash**       | Writes tags into your files                              |
| 🧩    | **metadata_plugin.bash**      | Registers metadata plugins with Arrbit                   |
| 📋    | **metadata_profiles.bash**    | Creates album‑type & status profiles                     |
| 🎵    | **track_naming.bash**         | Defines how tracks get renamed                           |
| 🎨    | **ui_settings.bash**          | Tweaks UI theme, date format, language                   |
| ✨    | **custom_scripts.bash**       | Hooks in your own post‑processing scripts                |
| 🏷️    | **custom_formats.bash**       | Loads your custom‑format JSON files                      |
| ⏱️    | **delay_profiles.bash**       | Sets download delays per source                          |
| 🎚️    | **quality_profile.bash**      | Defines quality cutoffs & allowed formats                |
| 📦    | **dependencies.bash**         | Installs system packages & Python libraries              |

---

## 📝 Configuration

1. **Edit your flags** in `/config/arrbit/config/arrbit.conf` to toggle features:
   ```bash
   INSTALL_COMMUNITY_PLUGINS="true"
   INSTALL_PLUGIN_DEEZER="true"
   INSTALL_PLUGIN_TIDAL="true"
   INSTALL_PLUGIN_TUBIFARRY="true"
   INSTALL_AUTOCONFIG="false"
   # …and per‑section flags…
