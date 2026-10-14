#pragma once
#include <QString>

// On-disk locations. The vault itself is wherever the user keeps it; these are the app's own files.
// `canvasPrefs` is the SAME file the Electron build writes (vaultPath, lastBoardId, auth counters), so both apps
// open the same vault. BCQ_DATA_DIR relocates everything under a scratch folder for tests.
namespace Paths {
QString appSupport();
QString electronDir();           // .../brotherhood-canvas (Electron userData)
QString canvasPrefs();           // shared with Electron
QString ownDir();                // .../BrotherhoodCanvasQt
QString ownPrefs();              // this app only: layout, snap, volume...
QString unlockToken();
QString defaultVault();          // ~/Documents/Brotherhood Canvas Vault
}
